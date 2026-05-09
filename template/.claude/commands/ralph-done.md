---
description: 개발자 "다 만들었다" 선언. QA → review-council → gap-analysis → CHECKLIST 의 4단 게이트 자동 실행.
---

이 커맨드는 4단 게이트를 순차로 돈다. 어디선가 막히면 거기서 멈추고 사용자에게 fix 후 재호출 안내.

## Step 1 — phase-qa-review

`phase-qa-review` 스킬 호출. 출력: `state/cycles/<N>/qa-findings.md`.
- 이슈 ≥1 또는 AC FAIL → status=FIXING_QA, **종료**. 사용자에게 fix 후 `/ralph-done` 재호출 안내.
- clean → 다음 단계.

## Step 2 — gate-verify(QA → COUNCIL) + review-council

`gate-verify(QA_REVIEW → REVIEW_COUNCIL)` → `review-council` 스킬 호출. 출력: `council-feedback.md`.
- verdict=REVISE → status=FIXING_COUNCIL, **종료**. 사용자에게 fix 후 `/ralph-done` 재호출 안내.
- verdict=PASS → 다음 단계.

## Step 3 — gate-verify(COUNCIL → GAP) + gap-analysis

`gap-analysis` 스킬 호출. 출력: `gaps.md`.
- CRITICAL ≥1 → status=FIXING_GAP, **종료**. fix 후 `/ralph-done` 재호출.
- 모두 OK → 다음 단계.

## Step 4 — gate-verify(GAP → CHECKLIST) + verify-loop-output

`verify-loop-output` 스킬 호출 (체크리스트 기반 객관 채점). 출력: `last-failures.md`.
- FAIL → status=FIXING_CHECK, **종료**. fix 후 `/ralph-done` 재호출.
- PASS → status=CYCLE_DONE, `cycles/<N>/done.md` 작성, **다음 단계 자동 진행**.

## Step 5 — project-stop-check (CYCLE_DONE 직후 자동)

`project-stop-check` 스킬 호출. CLAUDE.md "프로젝트 종료 조건" 을 누적 산출물과 대조.

- STOP 판정 → status=PROJECT_DONE. 사용자에게 종료 안내. `/ralph-cycle-start` 차단.
- CONTINUE 판정 → status=CYCLE_DONE 유지. 사용자에게 `/ralph-cycle-start` 로 다음 사이클 시작 안내.

수동 강제 종료가 필요하면 `/ralph-stop`.
