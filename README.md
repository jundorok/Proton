# Proton Calendar CLI (API 기반, 비공식)

이 저장소는 **Proton Calendar 일정 CRUD 전용 CLI**입니다.

- 대상: Proton Calendar만 사용
- 방식: Proton 오픈소스 내부 API 라이브러리 `go-proton-api` 사용
- 주의: Proton의 안정적인 공개 퍼블릭 Calendar API가 아니라 **내부/비공식 경로**입니다.

## 기능

- `calendars`: 캘린더 목록 조회
- `list`: 일정 목록 조회
- `get`: 일정 단건 조회
- `create`: 일정 생성
- `update`: 일정 수정
- `delete`: 일정 삭제

## 요구사항

- Go 1.24+
- 네트워크에서 Go 모듈 다운로드 가능해야 함
- Proton 계정 로그인 정보

환경 변수:

```bash
export PROTON_USERNAME="you@proton.me"      # 또는 PROTON_ACCOUNT
export PROTON_PASSWORD="your-login-password"
export PROTON_MAILBOX_PASSWORD="optional"   # 미설정 시 PROTON_PASSWORD 사용
```

## 실행

```bash
go run . calendars
go run . list --from 2026-02-20 --to 2026-02-28
go run . create --title "Team Sync" --start "2026-02-21T09:00" --end "2026-02-21T10:00"
go run . update --id "<EVENT_ID>" --title "Updated title"
go run . delete --id "<EVENT_ID>"
```

시간 입력 포맷:

- RFC3339: `2026-02-21T09:00:00+09:00`
- 로컬시간: `2026-02-21T09:00` 또는 `2026-02-21 09:00`
- 날짜만: `2026-02-21`

`create --all-day`를 쓰면 종일 일정으로 생성됩니다.

## 한계

- Proton 내부 API/암호화 스택 변경 시 동작이 깨질 수 있습니다.
- 2FA가 켜진 계정은 실행 중 OTP 입력이 필요할 수 있습니다.
- 이 환경에서는 외부 네트워크가 막혀 있어 실제 API 연동 테스트를 수행하지 못했습니다.
