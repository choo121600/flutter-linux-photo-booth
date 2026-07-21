# 빌드 & 검증 (Launchpad + 무하드웨어 게이트)

이 macOS 개발 호스트엔 `snapcraft`/`ubuntu-image`가 없고 대상은 Ubuntu Core(빌드 불가)
이므로, **snap 빌드는 Launchpad**, **이미지/재이미징은 리눅스+SD**로 수행합니다.

## A. Launchpad로 snap 빌드 (로컬 snapcraft 불필요)
booth 스냅과 (필요 시) 커스텀 gadget 스냅 모두 동일 방식.
1. 레포를 git 원격(GitHub/Launchpad)에 푸시.
2. https://launchpad.net → *Snap packages* → **Create snap package**:
   - Source: 해당 git 저장소/브랜치
   - Built for: **arm64, amd64**
   - Automatically upload to store: (선택)
3. **Request builds** → 빌드된 `.snap` 다운로드.

대안(리눅스 + snapcraft가 있을 때): `snapcraft remote-build --launchpad-accept-public-upload`
(모든 platforms 아키텍처를 Launchpad 팜에서 빌드). `--use-lxd`/`--destructive-mode`는
M1(arm64)에서 amd64를 만들지 못하므로 사용하지 않음.

## B. 무하드웨어 검증 (리눅스/VM)
```
snapcraft lint <booth>.snap                 # 라이브러리/링커 린트
review-tools.snap-review <booth>.snap        # 스토어급 confinement/인터페이스 검사
sudo snap install --dangerous <booth>.snap
snap connections ubu4cut                     # camera/cups/wayland 해소 확인 (cups-control 없어야)
# 데스크톱/VM에서 키오스크 daemon 렌더 확인:
sudo snap install ubuntu-frame
frame-it ubu4cut.ubu4cut-kiosk
```
확인 포인트:
- 이중 앱 엔트리(`ubu4cut`, `ubu4cut-kiosk`) 존재.
- 미사용 plug/슬롯 없음(network/network-bind/raw-usb/audio-playback/cups-control/com.test dbus 제거).
- `frame-it`로 daemon 앱이 Frame 안에서 렌더.

## C. grade devel → stable
`snap/snapcraft.yaml`의 `grade: devel`은 검증 전 안전값입니다. **B**의 무하드웨어 게이트와
**RPi5 수용 체크리스트**가 모두 통과한 뒤에만 `grade: stable`로 올려 재빌드하세요
(devel 스냅은 stable/candidate 채널 릴리스 불가).

## D. 스토어 자동연결 vs 사이드로드
- 스토어 설치 시 `cups`는 auto-connect.
- `--dangerous` 사이드로드는 전제 snap 자동설치/자동연결이 없으므로
  `setup-ubuntu-core.sh`가 cups/printer-app/인터페이스를 명시적으로 처리.

## E. 검증된 로컬 Docker 빌드 (arm64, Launchpad 불필요) — 실제 통과함

아래 절차로 **arm64 booth 스냅을 로컬에서 빌드·리뷰 통과**시켰습니다(EXIT=0, `review-tools.snap-review: pass`). Apple Silicon(arm64) + Docker에서 재현 가능. amd64는 amd64 호스트/컨테이너 또는 Launchpad로.

```bash
# 1) systemd(PID1) 컨테이너 (snapd는 systemd 필요)
docker run -d --name sc-build --privileged --cgroupns=host \
  --tmpfs /run --tmpfs /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  ubuntu:24.04 bash -c \
  "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq systemd systemd-sysv snapd; exec /sbin/init"

# 2) snapd + snapcraft
docker exec sc-build bash -c \
  "systemctl enable --now snapd.socket snapd.service && \
   snap wait system seed.loaded && snap install snapcraft --classic"

# 3) 소스 주입 (작업트리 그대로; 대용량/불필요 제외)
tar --exclude=./*.snap --exclude=./macos --exclude=./build --exclude=./.git \
  -czf - . | docker exec -i sc-build bash -c "rm -rf /build && mkdir /build && tar -xzf - -C /build"

# 4) 빌드 + 검증
docker exec sc-build bash -c \
  "cd /build && export PATH=/snap/bin:\$PATH && \
   snapcraft expand-extensions >/dev/null && \
   snapcraft --destructive-mode && \
   cp *.snap /root/ && cd /root && review-tools.snap-review *.snap"

# 5) 산출물 회수
docker cp sc-build:/build/ubu4cut_1.0.0_arm64.snap ./
```

결과물 `./ubu4cut_1.0.0_arm64.snap`(약 116MB, `grade: devel`)은 Pi에 사이드로드 가능:
`sudo snap install --dangerous ubu4cut_1.0.0_arm64.snap` (그 뒤 `ubuntu-core/setup-ubuntu-core.sh`).
