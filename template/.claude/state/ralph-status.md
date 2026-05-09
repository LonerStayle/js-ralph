# ralph status

cycle: 0
phase: NOT_STARTED
last_gate_verify: none
last_qa: none
last_council: none
fail_streak: 0

---

## phase 값 정의 (ralph-tick 가 이 순서로 자동 전진)

```
NOT_STARTED
   → RESEARCH
   → IDEATION
   → SPEC
   → IMPLEMENT_PENDING_FREEZE   ← 사람만 통과시킬 수 있음 (spec-frozen.flag)
   → IMPLEMENT
   → QA_REVIEW       ↔ FIXING_QA
   → REVIEW_COUNCIL  ↔ FIXING_COUNCIL
   → GAP_ANALYSIS    ↔ FIXING_GAP
   → CHECKLIST       ↔ FIXING_CHECK
   → CYCLE_DONE
   → (project-stop-check) → PROJECT_DONE  또는  NOT_STARTED (다음 사이클)
```

**STUCK_<phase>** — 같은 phase 에서 gate-verify FAIL 5회 연속 시 자동 진입. 다음 tick 부터 noop. 사람이 deficit.md 보고 개입 후 fail_streak 리셋.

**PROJECT_DONE** — project-stop-check STOP 또는 `/ralph-stop` 명시 호출 시. ralph-loop 도 종료 권고.

게이트 우회는 이 파일 직접 편집으로만 가능. 그 사실은 `ralph-history.md` 에 기록될 것.
