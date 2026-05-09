---
description: 프로젝트 종료를 사용자가 명시 선언. status=PROJECT_DONE 으로 굳히고 새 사이클 진입 차단. 정량 기준 미충족 상태에서도 강제 종료 가능.
---

사용자가 명시적으로 프로젝트 종료를 선언하는 커맨드.

1. `state/ralph-status.md` 의 `phase=PROJECT_DONE` 으로 갱신.
2. `state/cycles/<현재 N>/stop-check.md` 에 `결론: STOP (manual /ralph-stop)` 기록.
3. `state/ralph-history.md` 에 `[user-stop] <ISO ts>` append.
4. 이후 `/ralph-cycle-start` 호출은 차단 — "PROJECT_DONE 상태입니다. 재개하려면 status 파일을 직접 편집하세요." 안내.
