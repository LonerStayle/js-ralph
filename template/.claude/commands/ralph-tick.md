---
description: ralph-loop 가 매 iteration 호출하는 단일 entry. 현재 phase 1 step 만 전진시키고 즉시 종료. 사람이 수동으로도 호출 가능.
---

`ralph-tick` 스킬을 호출한다. 한 tick 은 정확히 한 step 만 수행:

1. 현재 `state/ralph-status.md` 의 phase 읽기
2. 해당 phase 의 표준 작업 1회 실행 (plan step 1개, council 1라운드, verify 1회 등)
3. gate-verify (해당되는 phase 만)
4. PASS 시 status 의 phase 를 다음으로 갱신, FAIL 시 같은 phase 유지 + deficit 기록
5. 즉시 종료 — 다음 step 은 다음 tick 이 함

ralph-loop 가 이 커맨드를 반복 invoke 하도록 설정해두면, 사람이 개입 없이 사이클이 자동 진행된다.

**유일한 사람 강제 인가 지점**: `IMPLEMENT_PENDING_FREEZE` phase. agent 가 spec.md 를 다 써도 `state/cycles/<N>/spec-frozen.flag` 가 없으면 IMPLEMENT 로 안 넘어간다. 사람이 검토 후 flag 생성하거나 `/ralph-spec-done` 호출.
