---
name: ralph-tick
description: ralph-loop 가 매 iteration 마다 호출하는 단일 entry. 현재 phase 를 읽어 1 step 만 전진시키고 종료한다. 자율 구동의 핵심.
---

# ralph-tick

## 핵심 규약

- **이 tick 안에서 정확히 한 step 만 수행**한다. 두 step 을 묶어 처리하지 않는다 (ralph-loop 가 다음 tick 을 호출할 것).
- 한 step = 현재 phase 의 표준 작업 + 그 phase 의 gate-verify + status 갱신.
- step 이 끝나면 즉시 exit. 다음 phase 의 작업은 다음 tick 이 한다.
- **gate-verify FAIL 시**: status 는 같은 phase 유지, 부족 항목을 `state/cycles/<N>/<phase>-deficit.md` 에 기록. 다음 tick 은 같은 phase 의 보강 작업을 수행.

## 절차

1. `state/ralph-status.md` 를 읽어 `cycle=N, phase=P` 추출.
2. P 가 `PROJECT_DONE` 이면 즉시 종료 (ralph-loop 에 cancel 권고 메시지만 출력).
3. P 가 `NOT_STARTED` 이면 → `/ralph-cycle-start` 와 동일 동작 (cycle=1, phase=RESEARCH 로 초기화). 이 tick 은 여기서 종료.
4. P 별 디스패치:

| phase | 이 tick 의 동작 | 통과 시 다음 phase | 비고 |
|-------|------------------|--------------------|------|
| RESEARCH | `phase-research` 스킬 1회 (research.md 작성/보강) → `gate-verify(RESEARCH→IDEATION)` | IDEATION | gate-verify FAIL 이면 같은 phase 유지 |
| IDEATION | `ideation-council` 스킬 (ideas.md 작성/보강) → `gate-verify(IDEATION→SPEC)` | SPEC | |
| SPEC | `phase-spec` 스킬 (spec.md 작성/보강) → `gate-verify(SPEC→IMPLEMENT)` | IMPLEMENT_PENDING_FREEZE | **사람 인가 대기** |
| IMPLEMENT_PENDING_FREEZE | (a) `.claude/config/spec-auto-freeze.flag` 존재 시 → `gate-verify(SPEC→IMPLEMENT)` 자동 실행, PASS 면 spec-frozen.flag 자동 생성. (b) 없으면 `state/cycles/<N>/spec-frozen.flag` 존재 여부만 확인 | IMPLEMENT (있을 때) / 같은 phase (없을 때) | (a) 자율 모드 — 사람 개입 0. (b) 게이트 모드 — 사람이 `/ralph-spec-done`. 하네스 시작 시 선택. |
| IMPLEMENT | `phase-implement` 1 step (plan.md 의 첫 미완료 step 1개만) | 모든 step 완료 시 QA_REVIEW | 한 tick = plan 의 1 step |
| QA_REVIEW | `phase-qa-review` 스킬 → `gate-verify(QA→COUNCIL)` | clean 시 REVIEW_COUNCIL / 이슈 시 FIXING_QA | |
| FIXING_QA | `phase-implement` 1 step (qa-findings.md 항목 fix) | 모두 fix 시 QA_REVIEW 재진입 | |
| REVIEW_COUNCIL | `review-council` → 결과에 따라 PASS / REVISE | PASS 시 GAP_ANALYSIS / REVISE 시 FIXING_COUNCIL | |
| FIXING_COUNCIL | `phase-implement` 1 step (council-feedback.md fix) | 모두 fix 시 REVIEW_COUNCIL 재진입 | |
| GAP_ANALYSIS | `gap-analysis` 스킬 | no gaps 시 CHECKLIST / gaps 시 FIXING_GAP | |
| FIXING_GAP | `phase-implement` 1 step (gaps.md CRITICAL fix) | 모두 fix 시 GAP_ANALYSIS 재진입 | |
| CHECKLIST | `verify-loop-output` (체크리스트 채점) | PASS 시 CYCLE_DONE / FAIL 시 FIXING_CHECK | |
| FIXING_CHECK | `phase-implement` 1 step (last-failures.md fix) | 모두 fix 시 CHECKLIST 재진입 | |
| CYCLE_DONE | `project-stop-check` 스킬 | STOP 시 PROJECT_DONE / CONTINUE 시 NOT_STARTED (다음 사이클 자동 시작) | |
| PROJECT_DONE | noop, 종료 메시지 | 변경 없음 | |

5. 매 phase 작업 후 `state/ralph-status.md` 갱신, `state/ralph-history.md` 에 `[tick] phase=P→P' verdict=...` append.
6. tick 종료.

## 자율 진행 안전장치

- **무한 FAIL 방지**: 같은 phase 에서 gate-verify FAIL 이 5회 연속 발생하면 status=STUCK_<phase> 로 표시하고 다음 tick 부터 noop. 사람이 deficit.md 보고 개입 요구.
- **SPEC freeze 모드 분기**:
  - 게이트 모드 (default, 안전 우선): agent 는 spec-frozen.flag 를 직접 못 만든다. 사람 `/ralph-spec-done` 만 가능.
  - 자율 모드 (`.claude/config/spec-auto-freeze.flag` 파일 존재 시): ralph-tick 이 gate-verify(SPEC→IMPLEMENT) PASS 후 spec-frozen.flag 자동 생성. **잘못된 spec 은 다층 방어 (REVIEW_COUNCIL → GAP_ANALYSIS → CHECKLIST) 가 잡는다는 가정**.
- **history 폭발 방지**: append-history.sh 가 같은 라인 연속 N개 이상이면 압축 (요약 라인으로 대체).
