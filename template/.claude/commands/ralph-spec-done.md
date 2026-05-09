---
description: SPEC 동결 선언. gate-verify 통과 시 IMPLEMENT 진입.
---

1. `gate-verify` 스킬 호출 (`from=SPEC, to=IMPLEMENT`).
2. PASS → phase=IMPLEMENT, `state/cycles/<N>/spec.md` 동결 (이후 변경은 cycle 종료 후 다음 사이클에서).
3. FAIL → spec 부족 항목 (acceptance criteria, 측정 지표, drop reason 등) 보고, SPEC 유지.
4. 통과 시 사용자에게 안내: "이제 `/ralph-start` 로 dev 플래너를 호출하세요."
