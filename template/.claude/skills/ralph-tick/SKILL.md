---
name: ralph-tick
description: ralph-loop 가 매 iteration 마다 호출하는 단일 entry. 현재 phase 를 읽어 1 step 만 전진시키고 종료한다. 자율 구동의 핵심.
---

# ralph-tick (v2)

## 핵심 규약

- **이 tick 안에서 정확히 한 step 만 수행**한다. 두 step 을 묶어 처리하지 않는다 (ralph-loop 가 다음 tick 을 호출할 것).
- 한 step = 현재 phase 의 표준 작업 + gate-verify (해당 phase 에 있는 경우) + status 갱신.
- step 이 끝나면 즉시 exit. 다음 phase 의 작업은 다음 tick 이 한다.
- **gate-verify FAIL 시**: status 는 같은 phase 유지. 부족 항목을 `state/cycles/<N>/<phase>-deficit.md` 에 기록. fail_streak++ 후 다음 tick 에서 같은 phase 보강 작업.
- **FAIL → IMPLEMENT 직회귀**: QA_REVIEW / REVIEW_COUNCIL / GAP_ANALYSIS / CHECKLIST 각 단계에서 이슈 발생 시 FIXING_* phase 없이 바로 IMPLEMENT 로 돌아간다.

## 절차

### Step 0: Telegram inbox 폴링 (phase 무관, 매 tick 서두에)

1. `notify-sender` 스킬을 통해 Telegram search_threads 폴링.
2. 새 대표님 reply 가 있으면 `.claude/state/inbox/<timestamp>.md` 에 저장 + `ralph-history.md` 에 `[telegram-reply] <summary>` append.
3. BLOCKED 상태인 chunk 와 매칭되는 응답이 있으면 manifest.md 의 해당 chunk status 를 PENDING 으로 되돌림.

### Step 1: 상태 로드

`state/ralph-status.md` 를 읽어 `cycle=N, phase=P, fail_streak=F` 추출.

### Step 2: PROJECT_DONE / STUCK 단락

- P 가 `PROJECT_DONE` → 종료 메시지 출력 후 즉시 exit (ralph-loop 에 cancel 권고).
- P 가 `STUCK_<phase>` → STUCK 우회 로직 실행 (아래 §STUCK 우회 참조).

### Step 3: Phase 디스패치

P 에 따라 아래 표의 동작 수행.

---

## Phase 디스패치 표 (v2)

| phase | 이 tick 의 1 step | 호출 스킬 | 통과 시 다음 phase | 갱신 state |
|-------|-------------------|-----------|-------------------|------------|
| NOT_STARTED | master-spec frontmatter `frozen` 확인. false/empty → `onboarding` 스킬 호출 (인터뷰 진행 + master-spec 합성). 대표님 "확정"/"OK"/"진행해" 발화 → `frozen: true` + `frozen_at: <ISO8601>` Edit → INTAKE 자동 전이. true → INTAKE 자동 전이 (FR-10) | `onboarding` | INTAKE | `ralph-status.md` (phase 갱신) |
| INTAKE | `intake/manifest.md` 의 `total_chunks > 0` 이면 noop (idempotency, R-8) → CHUNK_DETAIL 전이. 아니면 `phase-intake` 스킬 호출 → `intake/chunks/<i>.md` 생성 + `manifest.md` 작성 (status=PENDING) → gate-verify(INTAKE→CHUNK_DETAIL) | `phase-intake`, `gate-verify` | CHUNK_DETAIL | `manifest.md` (chunks + status), `ralph-status.md` |
| CHUNK_DETAIL | manifest 에서 다음 PENDING chunk 선택 → `chunk-detail` 스킬 호출 (페르소나 dispatch, dispatch_count 갱신) → gate-verify(CHUNK_DETAIL→SPEC) | `chunk-detail`, `gate-verify` | SPEC | `manifest.md` (dispatch_count++), `cycles/<N>/chunk-detail.md`, `ralph-status.md` |
| SPEC | `phase-spec` 스킬 호출 (chunk spec.md 작성/보강) → gate-verify(SPEC→IMPLEMENT) | `phase-spec`, `gate-verify` | IMPLEMENT | `cycles/<N>/spec.md`, `ralph-status.md` |
| IMPLEMENT | `phase-implement` 스킬 1 step (plan.md 의 첫 미완료 step 1개만) | `phase-implement` | 모든 step 완료 시 QA_REVIEW | `plan.md` (step 완료 표기), `ralph-history.md` |
| QA_REVIEW | `phase-qa-review` 스킬 → gate-verify(QA→COUNCIL) | `phase-qa-review`, `gate-verify` | clean → REVIEW_COUNCIL / 이슈 → **IMPLEMENT** (직회귀) | `cycles/<N>/qa-findings.md`, `ralph-status.md` |
| REVIEW_COUNCIL | `review-council` 스킬 (dispatch_count 확인, cap 적용) → 결과 판정 | `review-council`, `gate-verify` | PASS → GAP_ANALYSIS / 우려 → **IMPLEMENT** (직회귀) | `cycles/<N>/council-feedback.md`, `manifest.md` (dispatch_count++), `ralph-status.md` |
| GAP_ANALYSIS | `gap-analysis` 스킬 (master-spec chunk acceptance vs 실제 산출물 대조) | `gap-analysis`, `gate-verify` | no gaps → CHECKLIST / gaps → **IMPLEMENT** (직회귀) | `cycles/<N>/gaps.md`, `ralph-status.md` |
| CHECKLIST | `verify-loop-output` 스킬 (체크리스트 채점, runtime-evidence.md 필수 확인) | `verify-loop-output` | PASS → CYCLE_DONE / FAIL → **IMPLEMENT** (직회귀) | `cycles/<N>/last-failures.md`, `ralph-status.md` |
| CYCLE_DONE | 산출물 정리 + `cycles/<N>/runtime-evidence.md` 검증 → `notify-sender` 로 Telegram CYCLE_DONE 메시지 발사 → `project-stop-check` 호출 | `notify-sender`, `project-stop-check` | STOP → PROJECT_DONE / CONTINUE → 다음 chunk → CHUNK_DETAIL | `cycles/<N>/runtime-evidence.md`, `ralph-history.md` (`[notify] CYCLE_DONE`), `ralph-status.md` |
| PROJECT_DONE | Telegram 완료 보고 (`notify-sender`) → ralph-loop cancel 권고 메시지 출력 → exit | `notify-sender` | 변경 없음 | `ralph-history.md` (`[notify] PROJECT_DONE`) |
| STUCK_<phase> | STUCK 우회 로직 실행 (§STUCK 우회 참조) | `notify-sender` | 다음 PENDING chunk → CHUNK_DETAIL | `manifest.md`, `ralph-status.md`, `ralph-history.md` |

---

## NOT_STARTED 상세 동작 (FR-10)

1. `state/intake/master-spec.md` 를 읽어 frontmatter `frozen` 값 확인.
2. **frozen: true** 이면 → 즉시 `phase=INTAKE` 로 전이 후 exit.
3. **frozen: false 또는 파일 없음** 이면 → `onboarding` 스킬 호출.
   - onboarding 스킬이 대표님과 인터뷰 (8 질문) 진행 + master-spec.md 초안 합성.
   - 대화 중 "확정" / "OK" / "진행해" 발화 감지 OR `/ralph-spec-confirm` 호출 시:
     - `master-spec.md` frontmatter 를 Edit: `frozen: true`, `frozen_at: <ISO8601>`.
     - `ralph-history.md` 에 `[master-spec] frozen_at=<timestamp>` append.
     - `ralph-status.md` 를 `phase=INTAKE` 로 갱신.
   - 동결 없으면 이 tick 은 여기서 종료 (다음 tick 에서 인터뷰 계속).

---

## INTAKE 상세 동작 (FR-3, R-8 idempotency)

1. `state/intake/manifest.md` 존재 여부 확인.
2. **manifest.md 가 존재하고 `total_chunks > 0`** → noop. `ralph-status.md` 를 `phase=CHUNK_DETAIL` 로 갱신 후 exit (idempotency, R-8).
3. **manifest.md 없음 또는 `total_chunks = 0`** → `phase-intake` 스킬 호출:
   - master-spec.md 전체 → LLM chunk 분해 (`intake/chunks/<i>.md` 작성).
   - `intake/manifest.md` 생성 (모든 chunk status=PENDING, dispatch_count=0, deferral_count=0).
   - gate-verify(INTAKE→CHUNK_DETAIL) 실행.
   - PASS → `ralph-status.md` 를 `phase=CHUNK_DETAIL` 갱신.
   - FAIL → phase=INTAKE 유지, fail_streak++.

---

## STUCK 우회 (FR-11)

**진입 조건**: `fail_streak ≥ 5` 또는 현재 chunk 의 `deferral_count ≥ 3`

**동작 순서**:

1. `ralph-status.md` 를 `phase=STUCK_<현재phase>` 로 갱신.
2. `manifest.md` 의 현재 chunk status 를 `BLOCKED` 로 변경 + BLOCKED 사유 로그 append.
3. `notify-sender` 스킬로 Telegram STUCK 메시지 발사:
   - 형식: `⚠️ 막힘 발생 (chunk K)\n사유: <fail 원인>\n다음 행동: 다른 chunk 로 우회 / 대표님 한 줄 답 환영`
4. manifest 에서 다음 PENDING chunk 탐색.
   - PENDING chunk 없음 (전부 BLOCKED/DONE) → BLOCKED 비율 ≥ 50% 이면 `project-stop-check` 호출 (강제 종료 분기).
   - PENDING chunk 있음 → 해당 chunk 를 IN_PROGRESS 로 변경.
5. `ralph-status.md` 를 `phase=CHUNK_DETAIL, fail_streak=0` 으로 갱신.
6. `ralph-history.md` 에 `[stuck] chunk=K blocked → next=K' phase=CHUNK_DETAIL` append.

**대표님 reply 처리** (Step 0 inbox 폴링에서):
- BLOCKED chunk 와 매칭되는 Telegram reply 감지 시 해당 chunk status 를 PENDING 으로 되돌림.
- 다음 tick 에서 자연스럽게 CHUNK_DETAIL 로 진입 가능.

---

## CYCLE_DONE 상세 동작

1. `cycles/<N>/runtime-evidence.md` 존재 + 내용 검증 (미작성 시 CHECKLIST FAIL 로 되돌림).
2. `notify-sender` 스킬: Telegram CYCLE_DONE 메시지 발사.
   - 형식: `📊 사이클 N 완료\n기획: ...\n개발: ...\n다음 사이클: ...`
   - MCP 실패 시 `.claude/state/notifications.log` 에 append + ralph-history 에 `[notify] FAIL <reason>` 기록 (재시도 X, cycle 내 1회 attempt).
3. `project-stop-check` 스킬 호출:
   - 모든 chunk DONE → `phase=PROJECT_DONE`.
   - 미달 → 다음 PENDING chunk 를 IN_PROGRESS 로 변경 → `phase=CHUNK_DETAIL`.
4. `ralph-history.md` 에 `[cycle] N DONE → next=<phase>` append.

---

## 안전장치 요약

| 조건 | 동작 |
|------|------|
| fail_streak ≥ 5 | STUCK_<phase> 전이 → BLOCKED 표기 + Telegram + 우회 |
| deferral_count ≥ 3 | 동일 STUCK 동작 |
| 전체 chunk BLOCKED ≥ 50% | project-stop-check 강제 호출 |
| runtime-evidence.md 없음 | CHECKLIST FAIL 처리 (IMPLEMENT 직회귀) |
| Telegram MCP 실패 | notifications.log fallback, 재시도 없음 |
| INTAKE 이중 호출 | manifest.md 존재 시 noop (idempotency) |

---

## 매 tick 종료 후 공통 처리

- `state/ralph-status.md` 갱신 (cycle, phase, fail_streak, last_dispatch, last_telegram 포함).
- `state/ralph-history.md` 에 `[tick] cycle=N phase=P→P' verdict=<PASS|FAIL|STUCK>` append.
- tick 종료.

---

## 폐기 phase (v1 참조용)

> 아래 phase 들은 **v2 에서 제거**되었다. 이 SKILL.md 나 ralph-status.md 에서 정상 phase 로 사용해서는 안 된다.

| 폐기 phase | 제거 이유 |
|-----------|-----------|
| `RESEARCH` | CHUNK_DETAIL 로 통합 (FR-7) |
| `IDEATION` | CHUNK_DETAIL 로 통합 (FR-7) |
| `IMPLEMENT_PENDING_FREEZE` | master-spec 외부화로 불필요 (FR-8) |
| `FIXING_QA` | IMPLEMENT 직회귀로 단순화 (FR-6) |
| `FIXING_COUNCIL` | IMPLEMENT 직회귀로 단순화 (FR-6) |
| `FIXING_GAP` | IMPLEMENT 직회귀로 단순화 (FR-6) |
| `FIXING_CHECK` | IMPLEMENT 직회귀로 단순화 (FR-6) |

v1 phase 를 호출하는 슬래시 커맨드 (`/ralph-research-done`, `/ralph-ideation-done`, `/ralph-spec-done`, `/ralph-cycle-start`) 도 폐기. 호출 시 안내 메시지만 출력 (deprecated stub).
