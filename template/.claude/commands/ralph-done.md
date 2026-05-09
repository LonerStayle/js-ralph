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
- PASS → status=CYCLE_DONE, `cycles/<N>/done.md` 작성.

## CYCLE_DONE 후

사용자에게 안내:
- 다음 사이클을 시작하려면 `/ralph-cycle-start`.
- 종료하려면 그대로 둠 (status 는 CYCLE_DONE 유지).
