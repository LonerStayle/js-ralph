---
description: 첫 그린 라이트. bootstrap deploy + smoke test 실행. 통과 시 history 에 PASS 기록.
---

원칙 6 (배포 선세팅) 의 첫 그린 라이트를 잡는다.

1. `bash bootstrap/deploy.sh` 실행. 실패 시 즉시 중단하고 로그 출력.
2. `bash bootstrap/smoke-test.sh` 실행. 실패 시 중단.
3. 두 단계 모두 통과 → `memo/ralph-history.md` 에 `[deploy] PASS <timestamp>` append.
4. 이 entry 가 있어야 `/ralph-start` 가 동작한다.
