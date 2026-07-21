# RPi5 수용 체크리스트 (사용자 실기 검증)

무하드웨어 게이트(build/lint/review-tools/frame-it) 통과 후, 실제 RPi5 + Ubuntu Core에서
아래를 순서대로 확인합니다. 각 항목 통과 시 [ ] → [x].

## 0. 사전 (gadget/카메라·KMS)
- [ ] `ubuntu-core/gadget-camera-kms.md`대로 커스텀 이미지(카메라+풀 KMS)를 **예비 SD**에 굽고 부팅.
- [ ] `ls /dev/media*` 및 `/sys/class/video4linux/*/name`에 `rp1-cfe` 등장(센서 인식).
- [ ] `ls /dev/dri/`에 `card0`(풀 KMS) 존재.

## 1. 설치 & 배선
- [ ] `sudo snap install --dangerous ubu4cut_*.snap` (또는 스토어 설치).
- [ ] `sudo ubuntu-core/setup-ubuntu-core.sh` 실행(ubuntu-frame/cups/printer-app 설치·연결).
- [ ] `snap connections ubu4cut` → `camera`, `cups`, `wayland` 연결됨(`cups-control` 없음).

## 2. 키오스크 자동시작
- [ ] `snap services ubu4cut` → `ubu4cut-kiosk` **enabled/active**.
- [ ] 재부팅 후 Ubuntu Frame 안에서 부스 UI가 **자동 전체화면**으로 뜸.
- [ ] `snap logs ubu4cut.ubu4cut-kiosk -n 100`에 wayland/렌더 오류 없음.

## 3. 카메라 (CSI)
- [ ] 부스 프리뷰에 **실제 카메라 영상**이 표시(테스트 패턴 아님).
- [ ] `BOOTH_CAMERA_KIND=libcamera` 경로로 CSI가 잡힘(로그 `Camera: kind=libcamera`).
- [ ] (참고) 네컷 캡처 결과 이미지에 실제 영상이 담기는지 — **캡처 로직은 별도 트랙(IR2)**.
      현재 외부 Texture 캡처 한계로 빈 프레임일 수 있음(후속 이슈에서 appsink 직접 취득으로 수정).

## 4. 데스크톱 앱 (선택, 동일 snap)
- [ ] Ubuntu Desktop에서 앱 메뉴로 `ubu4cut` 수동 실행 → 정상 창.

## 5. 프린트 (USB 염료승화)
- [ ] 프린터 연결 후 Printer Application이 인식(`lpstat -p`에 등장).
- [ ] `lpadmin -d <printer>`로 기본 프린터 설정(또는 631 웹 UI).
- [ ] `snap set ubu4cut print.media=4x6 print.borderless=true` 반영.
- [ ] 부스에서 인쇄 실행 → 실제 4x6 출력물이 나옴(여백/색 확인).
- [ ] 실패 시 `snap logs`/`lpstat -W all`로 PNG→raster 필터/미디어 옵션 점검.

## 6. 정리
- [ ] 모든 항목 통과 후 `grade: stable`로 재빌드/재배포(선택).
- [ ] 예비 SD 검증 완료 후에만 운영 기기 재이미징(원본 롤백 이미지 보관).
