# CSI 카메라 + 풀 KMS 활성화 (커스텀 gadget/모델/재이미징)

> ⚠️ **실측 정정 2026-07-18:** Ubuntu Core **24**는 이 Pi5에서 풀 KMS가 안 된다(부트 펌웨어가 Pi5를
> 레거시 FB로 고정 — config.txt 오버레이(vc4-kms-v3d/-pi5/disable_fw_kms_setup)로 불가, 4회 재부팅 실증).
> **디스플레이 해법 = stock Ubuntu Core 26** (gadget이 이미 vc4-kms-v3d + disable_fw_kms_setup +
> camera_auto_detect 탑재) → `ubuntu-core/flash-and-verify.md` 옵션 A. 아래 커스텀 gadget 절차는
> `camera-csi` custom-device 슬롯이 필요할 때(옵션 B)만, 그때도 **Core 26(branch 26 / base core26)** 로 재타게팅.

> **자동화됨 (실측 2026-07-18, 이 레포 대상 기기 기준).** 아래 수동 절차는 배경 설명이고,
> 실제 실행은 리포의 스크립트로 대체된다:
> - `ubuntu-core/gadget/config.txt` — fkms→풀KMS + `camera_auto_detect=1` (`configs/config.txt` 드롭인)
> - `ubuntu-core/gadget/camera-csi-slot.yaml` — `camera-csi` custom-device 슬롯 (**snapcraft.yaml**에 append)
> - `ubuntu-core/sign-model.sh` → `ubuntu-core/build-image.sh` → `ubuntu-core/flash-and-verify.md`
>
> 실측 확인: 모델 `ubuntu-core-24-pi-arm64` **grade=signed**(→ dangerous 커스텀 모델 필수),
> config.txt가 `vc4-fkms-v3d`(Pi5에선 `/dev/fb0`만 뜨고 `/dev/dri` 없음), v4l 노드에 `rp1-cfe`
> 없음(ISP `pispbe-*` + HEVC `rpivid`만). 커널 `overlays/`엔 `vc4-kms-v3d`/`vc4-kms-v3d-pi5`,
> `imx708`/`imx219`/`ov5647` 등이 **이미 존재** → config.txt 두 줄만 고치면 열린다.

대상: `ubuntu-core-24-pi-arm64` (stock signed, brand Canonical). 연결 카메라는 **CSI**이며 stock
gadget(fkms + 카메라 미활성)에서 인식되지 않는다.

## 왜 필요한가 (실측 근거)
- gadget 소유 `config.txt`에 `camera_auto_detect`/센서 `dtoverlay` **없음** → `rp1-cfe`/센서 subdev 미생성.
- 그래픽이 `dtoverlay=vc4-fkms-v3d`(가짜 KMS) → Pi5에선 DRM/KMS 카드 미생성, Ubuntu Frame(Wayland)은 **`vc4-kms-v3d`(풀 KMS)** 필요.
- `snap get -d pi` = `{}`. **`snap set pi pi-config.*`는 고정 허용목록**(hdmi_*, disable_overscan, display_rotate, gpu_mem, framebuffer_* 등)만 지원 → `camera_auto_detect`/임의 `dtoverlay`는 **런타임 설정 불가**.
- stock **signed 모델은 외부 gadget으로 교체 불가** → 자체 dev key **커스텀(dangerous) 모델 + 재이미징** 필요.

## 목표 config.txt 라인 (→ `ubuntu-core/gadget/config.txt`에 반영됨)
```
# 풀 KMS (Wayland/Ubuntu Frame; Pi5는 fkms 미지원). /dev/dri/card0 생성.
dtoverlay=vc4-kms-v3d,cma-256
# 카메라 자동 감지 (또는 정확 센서: dtoverlay=imx708 등). start_x=1/gpu_mem은 쓰지 말 것(구 MMAL 스택).
camera_auto_detect=1
```
정확 센서 모델은 활성화 후 `cam --list`(libcamera-tools) 또는 `/sys/class/video4linux/*/name`(rp1-cfe 등장 확인)으로 식별.

## 절차
### 1) (먼저 시도) gadget 설정 경로 — 대개 불가
```
sudo snap set pi pi-config.camera-auto-detect=1   # 허용목록 밖이면 실패 → 커스텀 gadget으로
```

### 2) 커스텀 pi gadget
```
git clone https://github.com/canonical/pi-gadget -b 24   # Ubuntu Core 24 (모델 채널과 일치). classic-24는 Ubuntu Classic용.
```
- 부트 config.txt: 레포의 `ubuntu-core/gadget/config.txt`로 `configs/config.txt`를 교체.
- **custom-device 슬롯은 `snapcraft.yaml`의 top-level `slots:`에 추가한다 (gadget.yaml 아님).**
  snapcraft-빌드 gadget은 인터페이스 슬롯을 snapcraft.yaml에 선언하고, gadget.yaml은 볼륨/파티션
  레이아웃 전용이다. 내용 = `ubuntu-core/gadget/camera-csi-slot.yaml`:
```yaml
slots:
  camera-csi:
    interface: custom-device
    custom-device: camera-csi
    devices:
      - /dev/media[0-9]*
      - /dev/v4l-subdev[0-9]*
      - /dev/video[0-9]*
    read-devices:
      - /dev/rp1-cfe*
```
- gadget snap 빌드: 리눅스/컨테이너의 `snapcraft`. `build-image.sh`가 clone→패치→빌드까지 자동 수행.

### 3) 커스텀 모델 assertion (→ `ubuntu-core/model/ubu4cut-core-24-pi-arm64.model.json`)
- **개발/반복**: `grade: dangerous` 모델(로컬 unasserted gadget 부팅 허용). 단 **모델 서명 자체는 필요** —
  무료 Ubuntu One 개발자 계정 + `snapcraft register-key`로 등록한 dev key로 `snap sign`(→ `sign-model.sh`).
- **프로덕션**: 전용 brand 계정 key로 서명(grade signed).
- 모델에 커스텀 gadget(+ pi-kernel/core24/snapd/console-conf)을 명시. dangerous라 gadget은 로컬
  `--snap pi_*.snap`으로 오버라이드(id 불필요).

### 4) 이미지 빌드 + 재이미징 → `ubuntu-core/build-image.sh` + `flash-and-verify.md`
```bash
# 서명된 모델 생성:
BRAND_ID=<developer-id> KEY_NAME=ubu4cut \
  ubuntu-core/sign-model.sh ubuntu-core/model/ubu4cut-core-24-pi-arm64.model.json > ubu4cut.model
# 커스텀 gadget 빌드 + ubuntu-image (컨테이너; Apple Silicon OK) -> out/*.img.xz:
ubuntu-core/build-image.sh
# 예비 SD에 굽기 (원본 롤백 이미지 보관 필수):
xzcat out/*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync   # macOS는 flash-and-verify.md
```

### 5) 검증 (재이미징 후 실기)
```
ls /dev/dri/                                 # 풀 KMS: card0 존재
for f in /sys/class/video4linux/*/name; do cat $f; done | grep -i cfe   # rp1-cfe 등장
snap connections ubu4cut                     # camera/wayland/cups 연결
```

### 6) (선택 / iteration 2) 부스 스냅에 CSI custom-device 플러그
표준 `camera` 인터페이스(/dev/video* + /dev/media*)로 libcamera CSI가 부족할 때만. `snap/snapcraft.yaml`에
추가하고 부스 스냅을 **재빌드·재사이드로드**(재이미징 불필요; gadget엔 슬롯이 이미 있음):
```yaml
# top-level (앱의 plugs 목록에도 `camera-csi` 추가)
plugs:
  camera-csi:
    interface: custom-device
    custom-device: camera-csi
```
연결: `sudo snap connect ubu4cut:camera-csi pi:camera-csi`.
⚠️ custom-device는 super-privileged라 `review-tools.snap-review`가 snap-declaration을 요구한다 →
스토어 배포 전까지는 사이드로드(devel) 전용. 현재 무하드웨어 게이트의 review-tools 통과를 깨지 않으려면
이 플러그는 **카메라 컨파인먼트가 실제로 필요할 때** 추가할 것.

## 리스크 / 주의
- 재이미징은 **기기 전체 초기화** → 예비 SD 선검증 + 원본 롤백 이미지 보관 필수.
- dev key 서명 실수 시 부팅 불가 → 개발은 grade=dangerous 모델로.
- 커스텀 gadget/kernel/base rev는 core24와 정합해야 함.
