# RPi5 부스: 커스텀 Core 26 이미지 (로컬 로그인) — 네트워크 없이 첫 부팅 뚫기

## 왜 이 경로 (실측 결론)
| | KMS(디스플레이) | 온보드 WiFi |
|---|---|---|
| Core 24 (커널 6.8) | ❌ 레거시 FB 고정 | ✅ |
| Core 26 (커널 7.0) | ✅ | ❌ 스캔 죽음 (kernel 7.0 brcmfmac 리그레션) |

Core 26은 KMS를 고쳤지만 **온보드 WiFi 스캔이 죽어**, stock 이미지의 console-conf가 네트워크를 못 잡아 첫 부팅에서 막힌다.
**해결:** 커스텀 Core 26 모델(`grade: dangerous` + `system-user-authority: "*"`)로 이미지를 굽고, USB의
`auto-import.assert`로 **로컬 로그인 계정을 자동 생성**한다 → console-conf 없이 **파이 앞에서(터치 모니터 + Varmilo
키보드, KMS 정상) 로그인** → 쉘에서 WiFi를 직접 수리. (계정에 SSH키도 심어, WiFi 살아나면 `ssh ubu4cut@<ip>`도 됨)

## 준비물
예비 SD · **FAT32/ext4 USB 스틱 1개**(auto-import용) · USB 키보드 · 터치 모니터 · Ubuntu One 계정(이미 있음) · Docker

## 아티팩트 (레포에 준비됨)
- `ubuntu-core/model/ubu4cut-core-26-pi-arm64.model.json` — 커스텀 dangerous 모델 (console-conf 제외)
- `ubuntu-core/system-user.json` — 로컬 유저 템플릿 (SSH 공개키 이미 임베드)
- `ubuntu-core/sign-model.sh` · `build-image.sh` · `make-auto-import.sh`

## 절차
### 0) 컨테이너 + 스토어 로그인/키 등록 (인터랙티브 — 당신 터미널)
```bash
# 컨테이너 만들고 snapcraft 설치 (build-image.sh가 만드는 것과 동일)
docker run -d --name uc-imgbuild --privileged --cgroupns=host --tmpfs /run --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw ubuntu:24.04 bash -c \
  "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq systemd systemd-sysv snapd xz-utils openssl && exec /sbin/init"
sleep 60
docker exec uc-imgbuild bash -c "systemctl enable --now snapd.socket && snap wait system seed.loaded && snap install snapcraft --classic && snap install ubuntu-image --classic"

# 스토어 로그인 + 서명키 등록 (당신 Ubuntu One — 인터랙티브). snapcraft는 /snap/bin 전체경로로!
docker exec -it uc-imgbuild snap login
docker exec -it uc-imgbuild /snap/bin/snapcraft login
docker exec -it uc-imgbuild /snap/bin/snapcraft create-key ubu4cut   # 패스프레이즈: 그냥 Enter(빈값) 가능
docker exec -it uc-imgbuild /snap/bin/snapcraft register-key ubu4cut
docker exec uc-imgbuild /snap/bin/snapcraft whoami                       # developer-id 확인 (= BRAND_ID)

# 레포의 서명 자료를 컨테이너로
docker cp ubuntu-core uc-imgbuild:/root/ubuntu-core
```

### 1) 모델 서명 → ubu4cut.model
```bash
docker exec -e BRAND_ID=<developer-id> -e KEY_NAME=ubu4cut uc-imgbuild bash -lc \
  'cd /root && ubuntu-core/sign-model.sh ubuntu-core/model/ubu4cut-core-26-pi-arm64.model.json > ubu4cut.model && echo signed'
docker cp uc-imgbuild:/root/ubu4cut.model ./ubu4cut.model
```

### 2) 이미지 빌드 → out/*.img.xz
```bash
ubuntu-core/build-image.sh            # 컨테이너(uc-imgbuild) 재사용, ubuntu-image로 빌드
```

### 3) auto-import.assert 생성 (로컬 비번 설정) → USB
```bash
docker exec -it -e BRAND_ID=<developer-id> -e EMAIL=<ubuntu-one-이메일> -e KEY_NAME=ubu4cut uc-imgbuild \
  bash -lc 'cd /root && ubuntu-core/make-auto-import.sh ubuntu-core/system-user.json'   # 로컬 로그인 비번 입력
docker cp uc-imgbuild:/root/auto-import.assert ./auto-import.assert
# USB 스틱(FAT32) 루트에 복사:
cp ./auto-import.assert /Volumes/<USB이름>/auto-import.assert && sync
```

### 4) SD 굽기 + 부팅 (USB 꽂은 채로)
```bash
diskutil list                         # SD 확인 (예: /dev/disk5) — 내장 disk0 아님!
diskutil unmountDisk /dev/disk5
xzcat out/*.img.xz | sudo dd of=/dev/rdisk5 bs=4m
sync && diskutil eject /dev/disk5
```
SD를 파이에 꽂고, **auto-import.assert USB 스틱도 함께 꽂은 채** 전원 ON.

### 5) 로컬 로그인 (네트워크 불필요)
- 첫 부팅 후 **몇 분** 뒤 유저 생성됨(터치 모니터에 로그인 프롬프트). USB는 그 뒤 빼도 됨.
- 로그인: **username `ubu4cut`** + (3단계에서 정한 비번). → **쉘 획득** (KMS 덕에 화면 정상).

### 6) 쉘에서 WiFi 수리 → 온라인
```bash
sudo rfkill list                                   # wifi soft/hard block?
sudo rfkill unblock wifi
sudo iw reg set KR ; sudo iw reg get
dmesg | grep -i brcmfmac                            # 펌웨어/드라이버 에러 원인
sudo snap install network-manager                  # (온라인 전이라 실패하면, 아래로)
# 온보드가 끝내 안 되면 USB WiFi 동글(다른 칩셋) 꽂고 nmcli로 연결
ip -brief addr ; ip route                           # IP 확인
```
IP 나오면 나한테 알려주면 SSH로 이어받아 부스 설치까지 마무리.

## 참고
- 온보드 WiFi가 하드 리그레션이면 config로 못 고침 → **USB WiFi 동글** 또는 이더넷으로. (로컬 쉘이 있으니 진단·전환 자유로움)
- KMS/카메라는 Core 26 stock 게 이미 동작 → `ls /dev/dri/card0`, `rp1-cfe` 확인 후 `setup-ubuntu-core.sh`로 부스.
