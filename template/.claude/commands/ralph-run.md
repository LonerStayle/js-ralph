---
description: ralph 자율 루프 한 방 시작. /loop /ralph-tick 의 단축형. 모델 자가 페이싱으로 매 iteration 마다 ralph-tick 1 step 전진.
---

`loop` 스킬을 사용해 `/ralph-tick` 을 반복 호출한다.

- 인터벌은 지정하지 않는다 (모델 자가 페이싱 — 한 tick 끝난 다음 자연스럽게 다음 tick).
- 사용자가 명시 중단하기 전까지 자동으로 사이클을 돌린다.
- 중단: `ralph-loop:cancel-ralph` 또는 `/loop` 다시 호출로 취소.
- `IMPLEMENT_PENDING_FREEZE` 에서 `spec-auto-freeze.flag` 가 있으면 자동 통과, 없으면 noop 으로 사람 대기.
- `PROJECT_DONE` 도달 시 tick 이 noop 만 반복 — 그 시점에서 사용자가 cancel.
