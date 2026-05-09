# ralph status

cycle: 0
phase: NOT_STARTED
last_gate_verify: none
last_qa: none
last_council: none

---

## phase 값 정의

`NOT_STARTED` → `RESEARCH` → `IDEATION` → `SPEC` → `IMPLEMENT` →
`QA_REVIEW` ↔ `FIXING_QA` →
`REVIEW_COUNCIL` ↔ `FIXING_COUNCIL` →
`GAP_ANALYSIS` ↔ `FIXING_GAP` →
`CHECKLIST` ↔ `FIXING_CHECK` →
`CYCLE_DONE`

게이트 우회는 이 파일 직접 편집으로만 가능. 그 사실은 `ralph-history.md` 에 기록될 것.
