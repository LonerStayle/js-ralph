---
description: IDEATION 종료 선언. gate-verify 통과 시 SPEC 진입.
---

1. `gate-verify` 스킬 호출 (`from=IDEATION, to=SPEC`).
2. PASS → phase=SPEC, `phase-spec` 스킬 자동 진입.
3. FAIL → ideation 부족 항목 보고, IDEATION 유지.
