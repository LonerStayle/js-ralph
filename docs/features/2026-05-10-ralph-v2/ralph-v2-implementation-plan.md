---
commit_policy: per-task
---

# ralph-v2 구현계획서

> **For agentic workers:** REQUIRED SUB-SKILL: Use `js-super-subagent-driven-development` (recommended for 14 tasks) or `executing-plans`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** js-ralph factory template + 운영 모델을 v2 로 전면 재설계 — 외부 master-spec source-of-truth + 100% 자율 + Telegram 알림 3시점 + onboarding 진입점.

**Architecture:** Stop-hook self-loop 위에 LLM-driven phase machine (ralph-tick) 가 새 phase (INTAKE / CHUNK_DETAIL) 와 폐기 phase (RESEARCH / IDEATION / IMPLEMENT_PENDING_FREEZE / FIXING_*) 를 라우팅. State persistence 는 `.claude/state/intake/` (master-spec / chunks / manifest) + `cycles/<N>/` (runtime-evidence 추가). 외부 알림은 LLM tick 안에서 Telegram MCP 직호출.

**Tech Stack:** Markdown skill 본문 (LLM prompt 영역) + Bash hooks/scripts + YAML frontmatter (manifest schema) + Telegram MCP.

**Spec inputs:**

- `ralph-v2-requirements.md` — FR-1 ~ FR-11, NFR-1 ~ NFR-6, AC-1 ~ AC-5 (CH-20260510-001)
- `ralph-v2-tech-design.md` — D-1 ~ D-8 결정, R-1 ~ R-10 위험, §3 schemas (CH-20260510-002)

---

## 1. 단계별 작업

### Task 1: 메타 문서 갱신 (루트 CLAUDE.md + template/CLAUDE.md + README × 2)

**Files:**

- Modify: `CLAUDE.md` (루트)
- Modify: `template/CLAUDE.md`
- Modify: `README.md`
- Modify: `template/README.md`

**Model**: sonnet

- [ ] **Step 1: 루트 `CLAUDE.md` 의 7원칙 표 → 6원칙 + 운영 가정 + 동기 갱신**
  - 7원칙 표에서 "3. 플래너 패턴" 행 삭제 → 6원칙
  - "운영 가정" 섹션의 "사람 강제 인가 지점" 을 "master-spec 동결 1회 + PROJECT_DONE 검토 1회" 로 갱신
  - "동기 (왜 이 모양인가)" 섹션의 "사용자는 개발자" 를 "사용자는 대표님 (방향 결정자), 페르소나 = 직원" 으로 갱신
  - "루프 구조" 도표를 INTAKE → CHUNK_DETAIL → SPEC → IMPLEMENT → QA → COUNCIL → GAP → CHECKLIST 로 갱신 (FIXING_* 4 + IMPLEMENT_PENDING_FREEZE + RESEARCH + IDEATION 제거)

- [ ] **Step 2: `template/CLAUDE.md` 자가완결본 전면 재작성**

  주요 섹션:
  - 도메인 → "대표님 지시사항 — onboarding 가이드" 로 교체 (8 인터뷰 질문 catalog 명시, master-spec 동결 절차)
  - 운영 가정 — ralph-loop 자율 + master-spec 동결 1회 + PROJECT_DONE 검토 1회
  - 사용자 동기 — 대표님-직원 메타포
  - 6원칙 표 (플래너 행 제거)
  - 루프 구조 도표 갱신
  - 슬래시 커맨드 표 갱신 (폐기 4 + 신규 1)

- [ ] **Step 3: `README.md` (루트) 빠른 시작 단순화**
  - 1단계 — `bash scripts/new-harness.sh <name>` 만
  - 2단계 — `cd ~/jinsup_ralph/<name> && claude` (도메인 채우기 단계 사라짐)
  - 3단계 — claude 진입 시 ralph 가 자동 onboarding 인사 → 대표님 답변 → master-spec 동결
  - 4단계 — `/ralph-run` 자율 시작 → Telegram 진척 보고 받기
  - 5단계 — PROJECT_DONE 알림 후 띄워서 검증

- [ ] **Step 4: `template/README.md` 동일 톤으로 갱신** (5단계 + 톤 가이드 + Telegram chat_id 발급 안내)

- [ ] **Step 5: grep verify**

  Run:

  ```bash
  grep -E "7원칙|7대 원칙|플래너 패턴|FIXING_|IMPLEMENT_PENDING_FREEZE|RESEARCH→IDEATION|RESEARCH \(시장조사\)" CLAUDE.md template/CLAUDE.md README.md template/README.md
  ```

  Expected: 0 매칭 (또는 "v1 변화 요약" 같은 비교 표 안 only)

- [ ] **Step 6: Commit**

  ```bash
  git add CLAUDE.md template/CLAUDE.md README.md template/README.md
  git commit -m "feat(v2): 메타 문서 — 6원칙 + 대표님-직원 메타포 + onboarding 흐름"
  ```

---

### Task 2: state schema 파일 (ralph-status.md + intake/ placeholders)

**Files:**

- Modify: `template/.claude/state/ralph-status.md`
- Create: `template/.claude/state/intake/master-spec.md` (placeholder)
- Create: `template/.claude/state/intake/manifest.md` (placeholder)
- Create: `template/.claude/state/intake/chunks/.gitkeep`

**Model**: sonnet

- [ ] **Step 1: `template/.claude/state/ralph-status.md` phase 정의 표 갱신**

  **원본** (상단 메타) :

  ```markdown
  cycle: 0
  phase: NOT_STARTED
  ...
  ```

  **수정 후**:

  ```markdown
  cycle: 0
  phase: NOT_STARTED
  last_intake: null
  last_dispatch: null
  last_telegram: null
  fail_streak: 0

  ## phase 정의 (v2)
  NOT_STARTED → INTAKE → CHUNK_DETAIL → SPEC
    → IMPLEMENT → QA_REVIEW → REVIEW_COUNCIL → GAP_ANALYSIS
    → CHECKLIST → CYCLE_DONE → project-stop-check → PROJECT_DONE

  ## 폐기 phase (v1)
  RESEARCH, IDEATION, IMPLEMENT_PENDING_FREEZE, FIXING_QA, FIXING_COUNCIL, FIXING_GAP, FIXING_CHECK
  ```

- [ ] **Step 2: `template/.claude/state/intake/master-spec.md` placeholder 작성**

  ```markdown
  ---
  project: <project-name>
  version: 1
  frozen: false
  frozen_at: null
  ---

  # 비전
  <onboarding skill 이 대표님 인터뷰 결과로 합성>

  # 대상 사용자 / 시나리오
  <합성>

  # 핵심 산출물
  <합성>

  # 성공 정의
  <합성>

  # 금지 / 범위 밖
  <합성>

  # 외부 의존 / 제약
  <합성>
  ```

- [ ] **Step 3: `template/.claude/state/intake/manifest.md` placeholder**

  ```markdown
  ---
  total_chunks: 0
  generated_at: null
  generator: pending
  ---

  # Chunk Manifest

  ## 진행 표
  (phase-intake skill 이 master-spec 동결 후 채움)

  | chunk_id | title | status | cycle | dispatch_count | deferral_count |
  |----------|-------|--------|-------|----------------|----------------|

  ## 상태 정의
  - PENDING: 아직 cycle 진입 안 함
  - IN_PROGRESS: 현 cycle 진행 중
  - DONE: CHECKLIST PASS + project-stop-check 의 chunk 소진 인정
  - BLOCKED: STUCK 으로 보류

  ## counters
  - dispatch_count: council 단계에서 진짜 페르소나 dispatch 받은 횟수
  - deferral_count: acceptance 일부가 다른 chunk 로 이월된 횟수 (≥3 → BLOCKED)

  ## BLOCKED 사유 로그
  (STUCK 발생 시 phase-intake / ralph-tick 가 append)
  ```

- [ ] **Step 4: `template/.claude/state/intake/chunks/.gitkeep` 빈 파일 생성**

  ```bash
  mkdir -p template/.claude/state/intake/chunks && touch template/.claude/state/intake/chunks/.gitkeep
  ```

- [ ] **Step 5: grep verify**

  Run:

  ```bash
  ls template/.claude/state/intake/{master-spec.md,manifest.md,chunks/.gitkeep}
  grep -E "INTAKE|CHUNK_DETAIL" template/.claude/state/ralph-status.md
  ```

  Expected: 3 파일 존재 + ralph-status.md 에 INTAKE/CHUNK_DETAIL 언급

- [ ] **Step 6: Commit**

  ```bash
  git add template/.claude/state/
  git commit -m "feat(v2): state schema — intake/ + manifest 신설, ralph-status phase 정의 갱신"
  ```

---

### Task 3: ralph-tick skill 전면 재작성

**Files:**

- Modify: `template/.claude/skills/ralph-tick/SKILL.md`

**Model**: sonnet

- [ ] **Step 1: phase 디스패치 표 갱신**

  새 phase: NOT_STARTED, INTAKE, CHUNK_DETAIL, SPEC, IMPLEMENT, QA_REVIEW, REVIEW_COUNCIL, GAP_ANALYSIS, CHECKLIST, CYCLE_DONE, PROJECT_DONE, STUCK_<phase>.

  각 phase 의 동작 (1 step / 호출 스킬 / 갱신 state).

  **원본** (`template/.claude/skills/ralph-tick/SKILL.md`): 기존 phase 표 — RESEARCH/IDEATION/SPEC/IMPLEMENT_PENDING_FREEZE/IMPLEMENT/QA_REVIEW/FIXING_QA/REVIEW_COUNCIL/FIXING_COUNCIL/GAP_ANALYSIS/FIXING_GAP/CHECKLIST/FIXING_CHECK/CYCLE_DONE/PROJECT_DONE

  **수정 후**: 14 phase (FIXING_* 4 + IMPLEMENT_PENDING_FREEZE + RESEARCH + IDEATION 제거, INTAKE + CHUNK_DETAIL 추가)

- [ ] **Step 2: NOT_STARTED phase 동작 정의 (FR-10)**

  ```markdown
  ## NOT_STARTED — onboarding 진입점

  1. `.claude/state/intake/master-spec.md` Read — frontmatter `frozen` 검사
  2. `frozen: true` → INTAKE 자동 전이 + ralph-status 갱신
  3. `frozen: false` 또는 비어있음 → onboarding skill 호출 (LLM 인터뷰)
  4. 대표님이 "확정" 발화 → master-spec.md 의 frontmatter `frozen: true` + `frozen_at: <ISO 8601>` 로 Edit → 다음 tick 부터 INTAKE
  ```

- [ ] **Step 3: INTAKE phase 동작 (FR-3)**

  ```markdown
  ## INTAKE — chunk 분해 (1회만)

  1. `manifest.md` Read — `total_chunks > 0` 면 noop (idempotency, R-8 완화)
  2. master-spec.md 읽기 → phase-intake skill 호출 (LLM 자동 분해)
  3. 결과: chunks/<i>.md 작성 + manifest.md 갱신 (status=PENDING)
  4. CHUNK_DETAIL 로 자동 전이
  ```

- [ ] **Step 4: STUCK 우회 로직 (FR-11)**

  ```markdown
  ## STUCK_<phase> — 보류 후 우회

  1. 현 chunk 의 deferral_count ≥3 또는 fail_streak ≥5 → manifest 의 chunk status 를 `BLOCKED` 로 마크
  2. notify-sender skill 호출 (Telegram STUCK 메시지)
  3. manifest 의 다음 PENDING chunk 선택 → CHUNK_DETAIL 로 전이
  4. 대표님 reply 가 inbox 에 들어오면 다음 tick 에서 BLOCKED 해제 시도
  ```

- [ ] **Step 5: CYCLE_DONE 알림 호출**

  ```markdown
  ## CYCLE_DONE — 진척 보고

  1. cycles/<N>/ 산출물 정리 (runtime-evidence.md 존재 검증)
  2. notify-sender skill 호출 (Telegram CYCLE_DONE 메시지)
  3. project-stop-check skill 호출 → PROJECT_DONE / 다음 chunk 결정
  ```

- [ ] **Step 6: 폐기 phase 명시 + grep verify**

  Run:

  ```bash
  grep -E "RESEARCH|IDEATION|FIXING_QA|FIXING_COUNCIL|FIXING_GAP|FIXING_CHECK|IMPLEMENT_PENDING_FREEZE" template/.claude/skills/ralph-tick/SKILL.md
  ```

  Expected: "폐기 phase (v1)" 섹션 안에서만 매칭. dispatch table 본문엔 없어야.

- [ ] **Step 7: Commit**

  ```bash
  git add template/.claude/skills/ralph-tick/SKILL.md
  git commit -m "feat(v2): ralph-tick — NOT_STARTED onboarding + INTAKE + STUCK 우회 + 폐기 phase 정리"
  ```

---

### Task 4: phase-intake skill 신규

**Files:**

- Create: `template/.claude/skills/phase-intake/SKILL.md`

**Model**: sonnet

- [ ] **Step 1: SKILL.md 작성**

  ```markdown
  ---
  name: phase-intake
  description: master-spec.md 를 LLM 자동 chunk 분해 → chunks/<i>.md + manifest.md 생성. 1회만 (idempotent).
  model: sonnet
  ---

  # phase-intake

  ## 입력
  - `.claude/state/intake/master-spec.md` (대표님 동결본)

  ## 출력
  - `.claude/state/intake/chunks/01.md`, `02.md`, ... (chunk 별 상세)
  - `.claude/state/intake/manifest.md` (chunk 메타 + 카운터)

  ## idempotency
  - manifest.md 의 frontmatter `total_chunks > 0` 이면 noop. 재분해 원하면 사용자 명시 `/ralph-respec`.

  ## 분해 원칙 (LLM prompt)

  당신은 대표님의 master-spec 을 1 cycle 분량의 chunk 로 분해합니다.

  1. 모든 chunk 는 master-spec 의 명시 항목에서 도출. 새 가치 추가 금지.
  2. 1 chunk = 1 cycle. acceptance 5~10개. 너무 크면 sub-chunk 로.
  3. 의존성 있는 chunk 는 depends_on 에 명시.
  4. 각 chunk 의 출처 인용 (master-spec 의 어느 문단) 필수.

  ## 출력 schema
  - chunks/<i>.md: tech-design §3.2 schema
  - manifest.md: tech-design §3.3 schema (frontmatter total_chunks + 진행 표 + counters)
  ```

- [ ] **Step 2: grep verify**

  Run:

  ```bash
  test -f template/.claude/skills/phase-intake/SKILL.md && grep "name: phase-intake" template/.claude/skills/phase-intake/SKILL.md
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add template/.claude/skills/phase-intake/
  git commit -m "feat(v2): phase-intake skill — LLM 자동 chunk 분해"
  ```

---

### Task 5: chunk-detail skill 신규 (FR-7 RESEARCH+IDEATION 통합)

**Files:**

- Create: `template/.claude/skills/chunk-detail/SKILL.md`

**Model**: sonnet

- [ ] **Step 1: SKILL.md 작성**

  ```markdown
  ---
  name: chunk-detail
  description: 현 cycle chunk 의 구현 방안 + 디테일 발산을 1회로 통합 (v1 의 RESEARCH+IDEATION 대체)
  model: sonnet
  ---

  # chunk-detail

  ## 입력
  - `.claude/state/intake/chunks/<i>.md` (이번 cycle chunk)
  - `.claude/state/intake/master-spec.md` (참조용)

  ## 출력
  - `.claude/state/cycles/<N>/chunk-detail.md` (구현 방안 후보 + 디테일)
  - 다음 phase (SPEC) 입력으로 전달

  ## 원칙

  1. master-spec chunk 외 항목 추가 금지 (drift 방지). 새 가치 발굴 X.
  2. 구현 방안 후보 2-3 개 + 권장 + 트레이드오프
  3. acceptance 충족 디테일 (HOW)

  ## drift detection (gate-verify 가 호출 시)
  - chunk-detail.md 의 항목들이 chunks/<i>.md 의 acceptance 안 ⊆ 인지
  - 위반 시 FAIL → IMPLEMENT 직회귀
  ```

- [ ] **Step 2: grep verify + Commit**

  ```bash
  test -f template/.claude/skills/chunk-detail/SKILL.md
  git add template/.claude/skills/chunk-detail/
  git commit -m "feat(v2): chunk-detail skill — RESEARCH+IDEATION 통합 (FR-7)"
  ```

---

### Task 6: onboarding skill 신규 (FR-10)

**Files:**

- Create: `template/.claude/skills/onboarding/SKILL.md`

**Model**: sonnet

- [ ] **Step 1: SKILL.md 작성 — 8 질문 인터뷰**

  ```markdown
  ---
  name: onboarding
  description: 새 하네스 진입 시 대표님께 8 질문 인터뷰 → master-spec.md 합성 → "확정" 발화 시 동결
  model: sonnet
  ---

  # onboarding

  ## 트리거
  - ralph-tick 의 NOT_STARTED phase 가 master-spec.md 의 `frozen: false` 감지 시 호출

  ## 인터뷰 8 질문 catalog

  1. 이 프로젝트 한 줄 비전?
  2. 누가 사용? (1-2 문장 페르소나)
  3. 핵심 산출물 1-3개?
  4. "성공" 의 정의 (정량 + 정성)?
  5. 절대 만들지 말 것 (범위 밖)?
  6. 외부 의존 (API / 데이터 소스 / 사용자 입력)?
  7. 규모 / 일정 / 비용 cap (cycles ≤ N)?
  8. Telegram chat_id (이걸로 진척 보고드림. 발급 안 됐으면 /telegram:configure 안내)

  ## 부족 응답 처리
  - 모호하면 1-2 round 추가 질문 (무한 X)
  - 끝까지 모호 → master-spec 에 "확정 필요" 표기 + 다음 phase 진입 시 알림

  ## 합성 → master-spec.md
  - 인터뷰 결과를 tech-design §3.1 schema 로 매핑
  - frontmatter `frozen: false` 로 작성 → 대표님 review

  ## 동결 트리거 (D-6 결정)
  - 키워드: 대화 중 "확정" / "OK" / "진행해" / "동결" / "frozen" 감지
  - 슬래시: `/ralph-spec-confirm` (선택)
  - 둘 다 발생 시 master-spec.md frontmatter `frozen: true` + `frozen_at: <ISO 8601>` Edit
  ```

- [ ] **Step 2: grep verify + Commit**

  ```bash
  grep -E "8 질문|frozen: true" template/.claude/skills/onboarding/SKILL.md
  git add template/.claude/skills/onboarding/
  git commit -m "feat(v2): onboarding skill — 8 인터뷰 질문 + master-spec 동결 (FR-10)"
  ```

---

### Task 7: notify-sender skill + notify.md config

**Files:**

- Create: `template/.claude/skills/notify-sender/SKILL.md`
- Create: `template/.claude/config/notify.md`

**Model**: sonnet

- [ ] **Step 1: notify-sender SKILL.md 작성**

  ```markdown
  ---
  name: notify-sender
  description: Telegram MCP 직호출로 CYCLE_DONE/STUCK/PROJECT_DONE 발사 + 대표님 reply 폴링
  model: sonnet
  ---

  # notify-sender

  ## 호출 시점 (FR-9)
  - CYCLE_DONE: ralph-tick 의 CYCLE_DONE phase 가 호출
  - STUCK: ralph-tick 의 STUCK_<phase> 진입 시 호출
  - PROJECT_DONE: project-stop-check skill 의 STOP 판정 시 호출

  ## 발사 (push)
  도구: `mcp__plugin_telegram_telegram__reply` (또는 동등 tool)

  파라미터:
  - chat_id: notify.md 의 telegram_chat_id
  - message: 시점별 schema (notify.md 참조)

  ## 폴링 (대표님 reply)
  - ralph-tick 의 매 iteration 시작 시 호출
  - `mcp__plugin_telegram_telegram__search_threads` + `get_thread`
  - 새 메시지 → `.claude/state/inbox/<timestamp>.md` 저장 + ralph-history append

  ## 메시지 schema (대표님 톤 — NFR-2)
  - 비기술 언어 (jargon 1줄 풀어서)
  - "기획 / 개발 / 다음 방향" 분리
  - 3-5줄 핵심 + 상세 링크 (선택)

  ## fallback (R-2 / R-6)
  - MCP 실패 시 `.claude/state/notifications.log` append + ralph-history `[notify] FAIL <reason>`
  - 재시도 X (cycle 내 1회만)
  - chat_id 미설정 시 master-spec 에 "telegram_chat_id MISSING" 표기 + 콘솔 fallback
  ```

- [ ] **Step 2: notify.md config 작성**

  ```markdown
  # Notify Config

  telegram_chat_id: <onboarding 8번째 질문에서 받음>
  default_channel: telegram

  ## 메시지 schema

  | 시점 | 형식 |
  |------|------|
  | CYCLE_DONE | 📊 사이클 N 완료\n기획: ...\n개발: ...\n다음 사이클: ... |
  | STUCK | ⚠️ 막힘 발생 (chunk K)\n사유: ...\n다음 행동: 다른 chunk 로 우회 / 대표님 한 줄 답 환영 |
  | PROJECT_DONE | 🎉 프로젝트 완료\n완료/보류 chunk: a/b\n검증: docker compose up\n보류 항목: ... |

  ## 톤 가이드
  - 비기술 언어 (jargon 사용 시 1줄 풀어서 설명)
  - "기획 / 개발 / 결정 / 다음 방향" 분리
  - 3-5 줄 핵심 + (선택) 상세 링크
  ```

- [ ] **Step 3: grep verify + Commit**

  ```bash
  grep -E "telegram_chat_id|notify-sender" template/.claude/config/notify.md template/.claude/skills/notify-sender/SKILL.md
  git add template/.claude/skills/notify-sender/ template/.claude/config/notify.md
  git commit -m "feat(v2): notify-sender skill + notify.md config — Telegram 3시점 알림 (FR-9)"
  ```

---

### Task 8: 갱신 4 스킬 — gate-verify / gap-analysis / project-stop-check / review-council

**Files:**

- Modify: `template/.claude/skills/gate-verify/SKILL.md`
- Modify: `template/.claude/skills/gap-analysis/SKILL.md`
- Modify: `template/.claude/skills/project-stop-check/SKILL.md`
- Modify: `template/.claude/skills/review-council/SKILL.md`

**Model**: sonnet

- [ ] **Step 1: gate-verify — runtime evidence 항목 추가 (FR-5 함정 3)**

  추가 검증 항목:

  ```markdown
  ## CHECKLIST phase 시 추가 검증

  - [ ] `.claude/state/cycles/<N>/runtime-evidence.md` 존재
  - [ ] runtime-evidence.md 안에 "자동 검증" 섹션 + "캡처" 섹션 모두 채워짐
  - 미충족 → CHECKLIST FAIL → IMPLEMENT 직회귀
  ```

  추가 drift detection:

  ```markdown
  ## CHUNK_DETAIL → SPEC 전이 시
  - 본 cycle 산출물 항목들 ⊆ chunks/<i>.md 의 acceptance 인지 검증
  - 위반 시 FAIL (drift)
  ```

- [ ] **Step 2: gap-analysis — master-spec chunk 비교로 변경 (FR-3)**

  **원본** : "ralph 가 만든 spec.md vs 산출물" 비교

  **수정 후**: "master-spec chunks/<i>.md vs 산출물" 비교

- [ ] **Step 3: project-stop-check — chunk 소진 + acceptance PASS 기준 (FR-4)**

  **원본**: 자동 메트릭 (예: 카드 ≥30 등 도메인 메트릭)

  **수정 후**:

  ```markdown
  ## STOP 판정 기준 (v2)

  1. manifest.md 의 모든 chunk status 가 DONE 또는 BLOCKED
  2. DONE chunk 들 모두 CHECKLIST PASS (cycles/<N>/checklist-result.md 검증)
  3. 비용 cap 도달 (cycles ≤ N from master-spec, 있으면)

  → STOP → status.phase=PROJECT_DONE → notify-sender (PROJECT_DONE 알림)

  ## BLOCKED 비율 ≥50% 시 자동 STOP (R-3 완화)
  - 진척 0 방지. Telegram 알림 + 대표님 개입 요청
  ```

- [ ] **Step 4: review-council — dispatch 최소 cap (FR-5 함정 5)**

  추가 룰:

  ```markdown
  ## dispatch cap 강제 (FR-5 함정 5)

  manifest.md 의 dispatch_count 와 ralph-status 의 last_dispatch 검사:

  1. 현 cycle = STOP 직전 cycle (manifest 모든 chunk status 가 DONE 또는 IN_PROGRESS) → 무조건 진짜 dispatch
  2. (현 cycle - last_dispatch_cycle) ≥ 2 → 무조건 진짜 dispatch
  3. 그 외 → 메인 self-synth OK

  진짜 dispatch = 페르소나 agent 를 Agent tool 로 실 호출 (Task tool / general-purpose 등)

  dispatch 후 manifest.md 의 dispatch_count++ + ralph-status.md 의 last_dispatch 갱신.
  ```

- [ ] **Step 5: grep verify**

  ```bash
  grep -E "runtime-evidence|master-spec chunk|chunk 소진|dispatch_count|last_dispatch" \
    template/.claude/skills/{gate-verify,gap-analysis,project-stop-check,review-council}/SKILL.md
  ```

  Expected: 4 파일 모두 새 키워드 매칭

- [ ] **Step 6: Commit**

  ```bash
  git add template/.claude/skills/{gate-verify,gap-analysis,project-stop-check,review-council}/
  git commit -m "feat(v2): 4 skill 갱신 — runtime evidence + master-spec chunk + 소진 기준 + dispatch cap"
  ```

---

### Task 9: 갱신 2 스킬 — phase-implement / phase-spec

**Files:**

- Modify: `template/.claude/skills/phase-implement/SKILL.md`
- Modify: `template/.claude/skills/phase-spec/SKILL.md`

**Model**: sonnet

- [ ] **Step 1: phase-implement — 플래너 사전 호출 단계 제거 (FR-1)**

  플래너 호출 단계 모두 삭제. dev 페르소나가 직접 IMPLEMENT.

- [ ] **Step 2: phase-spec — chunk 상세화 의미로 좁힘 (FR-3)**

  **원본**: "spec.md 동결" 중심

  **수정 후**: "chunks/<i>.md 의 acceptance 를 cycle 의 구체 spec 으로 상세화" + "spec source-of-truth 는 master-spec, 본 phase 는 chunk 의 cycle 단위 계획"

- [ ] **Step 3: grep verify**

  ```bash
  grep -E "플래너|planner" template/.claude/skills/phase-implement/SKILL.md  # 0 매칭 expected
  grep -E "chunks/|master-spec" template/.claude/skills/phase-spec/SKILL.md  # 1+ expected
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add template/.claude/skills/{phase-implement,phase-spec}/
  git commit -m "feat(v2): phase-implement 플래너 제거 + phase-spec chunk 상세화"
  ```

---

### Task 10: 폐기 2 스킬 디렉터리 삭제

**Files:**

- Delete: `template/.claude/skills/phase-research/`
- Delete: `template/.claude/skills/ideation-council/`

**Model**: haiku

- [ ] **Step 1: 디렉터리 삭제**

  ```bash
  rm -rf template/.claude/skills/phase-research/
  rm -rf template/.claude/skills/ideation-council/
  ```

- [ ] **Step 2: 부재 verify**

  ```bash
  test ! -e template/.claude/skills/phase-research/
  test ! -e template/.claude/skills/ideation-council/
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add -A template/.claude/skills/
  git commit -m "feat(v2): 폐기 — phase-research / ideation-council (chunk-detail 으로 통합)"
  ```

---

### Task 11: 페르소나 15개 톤 갱신 (FR-2 + FR-1)

**Files:**

- Modify: `template/.claude/agents/pm/{pm-strategic,pm-user-empathic,pm-metrics-driven}.md`
- Modify: `template/.claude/agents/dev/{dev-architect,dev-pragmatist,dev-security-paranoid}.md`
- Modify: `template/.claude/agents/qa/{qa-edge-case,qa-regression,qa-ux}.md`
- Modify: `template/.claude/agents/designer/{designer-pixel-perfect,designer-ux-first,designer-contrarian}.md`
- Modify: `template/.claude/agents/marketer/{marketer-growth,marketer-brand,marketer-conversion}.md`

**Model**: sonnet

- [ ] **Step 1: 모든 페르소나 frontmatter description 에 "대표님 호칭, 보고체 톤" 추가**

  공통 추가 텍스트 (description 끝에):

  ```
  사용자를 "대표님" 으로 호칭하고, 발화 시 "대표님께 보고드립니다" 형식의 보고체를 사용한다.
  ```

- [ ] **Step 2: dev/* 3 페르소나에서 플래너 책임 명시 제거 (FR-1)**

  "구현 전 플래너 호출 강제" / "step plan 생성 책임" 등 플래너 관련 문구 grep + 삭제. 페르소나 자체는 보존.

- [ ] **Step 3: 모든 산출물 톤 가이드 (council 발화 / QA findings / GAP 분석) 도 보고체 명시**

  각 페르소나의 본문에 한 줄 추가:

  ```
  발화 / 보고서 / 산출물 모두 "대표님께 보고드립니다" 형식. 비기술 언어 권장 (대표님이 실무 상세 모름 가정).
  ```

- [ ] **Step 4: grep verify**

  ```bash
  for f in template/.claude/agents/{pm,dev,qa,designer,marketer}/*.md; do
    grep -q "대표님" "$f" || echo "MISSING 대표님: $f"
  done
  grep -E "플래너|planner" template/.claude/agents/dev/*.md  # 0 매칭 expected
  ```

  Expected: 모든 페르소나에 대표님 키워드, dev/* 에 플래너 부재.

- [ ] **Step 5: Commit**

  ```bash
  git add template/.claude/agents/
  git commit -m "feat(v2): 15 페르소나 톤 — 대표님-직원 메타포 + dev 플래너 책임 제거"
  ```

---

### Task 12: 슬래시 커맨드 정리

**Files:**

- Delete: `template/.claude/commands/{ralph-research-done,ralph-ideation-done,ralph-spec-done,ralph-cycle-start}.md`
- Modify: `template/.claude/commands/ralph-run.md`
- Create: `template/.claude/commands/ralph-respec.md` (선택, 신규)

**Model**: sonnet

- [ ] **Step 1: 폐기 4개 삭제**

  ```bash
  rm template/.claude/commands/{ralph-research-done,ralph-ideation-done,ralph-spec-done,ralph-cycle-start}.md
  ```

- [ ] **Step 2: ralph-run.md 갱신 — onboarding 자동 진입 반영 (FR-10)**

  본문에 추가:

  ```markdown
  ## 자동 onboarding 진입
  - 새 하네스에서 첫 호출 시 master-spec.md frozen=false → onboarding skill 발화
  - master-spec 동결 후 INTAKE → CHUNK_DETAIL → cycle 시작
  ```

- [ ] **Step 3: ralph-respec.md 신규 (선택)**

  ```markdown
  ---
  description: master-spec 갱신 후 INTAKE 재실행 트리거 (R-8 idempotency 우회)
  ---

  master-spec.md 를 사람이 직접 수정한 후 호출. manifest.md 를 비우고 INTAKE phase 로 재진입한다.
  주의: 진행 중 chunk 상태가 사라질 수 있음. 백업 후 사용 권장.
  ```

- [ ] **Step 4: grep verify**

  ```bash
  test ! -e template/.claude/commands/ralph-research-done.md
  test ! -e template/.claude/commands/ralph-ideation-done.md
  test ! -e template/.claude/commands/ralph-spec-done.md
  test ! -e template/.claude/commands/ralph-cycle-start.md
  test -e template/.claude/commands/ralph-respec.md
  grep -E "onboarding|master-spec" template/.claude/commands/ralph-run.md
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add -A template/.claude/commands/
  git commit -m "feat(v2): 슬래시 커맨드 정리 — 폐기 4 + ralph-run onboarding + ralph-respec 신규"
  ```

---

### Task 13: scripts/verify-v2-template.sh 신규 (AC-5 정적 검증)

**Files:**

- Create: `scripts/verify-v2-template.sh`

**Model**: sonnet

- [ ] **Step 1: 정적 grep 검증 스크립트 작성**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  TEMPLATE="$ROOT/template"
  fail() { echo "FAIL: $1" >&2; exit 1; }

  # AC-5: phase 정의 표 갱신
  grep -q "INTAKE" "$TEMPLATE/.claude/state/ralph-status.md" || fail "ralph-status 에 INTAKE 부재"
  grep -q "CHUNK_DETAIL" "$TEMPLATE/.claude/state/ralph-status.md" || fail "ralph-status 에 CHUNK_DETAIL 부재"

  # AC-1: 신규 스킬 존재
  for s in onboarding phase-intake chunk-detail notify-sender; do
    test -d "$TEMPLATE/.claude/skills/$s" || fail "$s skill 부재"
  done

  # AC-1: 폐기 스킬 부재
  for s in phase-research ideation-council; do
    test ! -e "$TEMPLATE/.claude/skills/$s" || fail "$s skill 미삭제"
  done

  # AC-1: state/intake placeholder
  test -f "$TEMPLATE/.claude/state/intake/master-spec.md" || fail "master-spec.md 부재"
  test -f "$TEMPLATE/.claude/state/intake/manifest.md" || fail "manifest.md 부재"

  # AC-1: notify config
  test -f "$TEMPLATE/.claude/config/notify.md" || fail "notify.md 부재"

  # AC-1: 페르소나 대표님 키워드
  for f in "$TEMPLATE"/.claude/agents/{pm,dev,qa,designer,marketer}/*.md; do
    grep -q "대표님" "$f" || fail "$f 에 '대표님' 부재"
  done

  # AC-1: 6원칙 (7원칙 부재)
  ! grep -E "^\| 7\." "$ROOT/CLAUDE.md" 2>/dev/null || fail "루트 CLAUDE.md 에 7원칙 잔존"
  ! grep -E "^\| 7\." "$TEMPLATE/CLAUDE.md" 2>/dev/null || fail "template CLAUDE.md 에 7원칙 잔존"

  # AC-1: 폐기 슬래시 커맨드 부재
  for c in ralph-research-done ralph-ideation-done ralph-spec-done ralph-cycle-start; do
    test ! -e "$TEMPLATE/.claude/commands/$c.md" || fail "$c.md 미삭제"
  done

  echo "verify-v2-template: ALL PASS"
  ```

- [ ] **Step 2: 실행 테스트 (Task 1~12 가 끝난 후)**

  ```bash
  chmod +x scripts/verify-v2-template.sh
  bash scripts/verify-v2-template.sh
  ```

  Expected: "verify-v2-template: ALL PASS"

- [ ] **Step 3: Commit**

  ```bash
  git add scripts/verify-v2-template.sh
  git commit -m "feat(v2): verify-v2-template.sh 정적 검증 스크립트 (AC-5)"
  ```

---

### Task 14: e2e 검증 가이드 (AC-4) + show-money 마이그레이션 안내

**Files:**

- Create: `docs/v2-rollout-guide.md`

**Model**: sonnet

- [ ] **Step 1: 롤아웃 가이드 작성**

  ```markdown
  # ralph-v2 롤아웃 가이드

  ## 1. e2e 검증 (AC-4)

  새 하네스 1개 eject → onboarding → INTAKE → cycle 1 chunk 1 자율 완주 (코드까지).

  ```bash
  bash scripts/new-harness.sh test-v2
  cd ~/jinsup_ralph/test-v2
  claude
  ```

  Claude 진입 후 ralph 가 즉시 "대표님 안녕하십니까" 발화 확인 → 8 인터뷰 답변 → "확정" 발화 → INTAKE 자동 → CHUNK_DETAIL 자동 → ... → CYCLE_DONE 시 Telegram 알림 1회.

  ## 2. show-money 마이그레이션 (선택, out-of-scope)

  show-money 는 v1 기준 cycle 6 PROJECT_DONE 상태. v2 마이그레이션 = 본질적으로 새 master-spec 작성. 아래 절차는 사용자가 결정 시:

  1. 백업: `cp -R ~/jinsup_ralph/show-money ~/jinsup_ralph/show-money.v1.bak`
  2. v2 template 으로 .claude/ 일부 갱신 (수동 cp)
  3. 새 master-spec.md 작성 (postmortem priority 1~4 반영 — LLM 파이프라인 / 도메인 좁히기 / UX / STOP 재정의)
  4. /ralph-respec → INTAKE 재진입

  ## 3. v1 ↔ v2 호환 (R-10)

  폐기 슬래시 커맨드 (ralph-research-done 등) 는 v2 에서 즉시 삭제. 기존 하네스 (show-money/GodMode/PlanB) 가 호출 시 깨짐. 사용자 책임으로 폐기 또는 마이그레이션.
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add docs/v2-rollout-guide.md
  git commit -m "docs(v2): rollout 가이드 — e2e 검증 + 마이그레이션 안내"
  ```

---

## 2. 위험 코드 지점

tech-design §6 의 R-1 ~ R-10 + 코드 위치 + 완화. 카테고리는 risk-annotation taxonomy (`side-effect | breaking | race`).

- `template/.claude/skills/phase-intake/SKILL.md:분해_prompt` — **side-effect** (R-1 chunk 분해 의도 어긋남): chunk 분해 prompt 에 "master-spec 인용 강제" + AC-4 e2e 검증으로 cycle 1 catch
- `template/.claude/skills/notify-sender/SKILL.md:fallback` — **side-effect** (R-2 MCP 끊김): MCP 실패 시 .claude/state/notifications.log fallback + 재시도 X
- `template/.claude/skills/project-stop-check/SKILL.md:BLOCKED_비율_체크` — **side-effect** (R-3 모든 chunk BLOCKED): BLOCKED ≥50% 자동 PROJECT_DONE 강제
- `template/.claude/skills/onboarding/SKILL.md:추가_질문_round` — **side-effect** (R-4 인터뷰 응답 모호): 1-2 round 추가 질문, 무한 X. 모호 시 master-spec 에 "확정 필요" 표기
- `template/.claude/skills/review-council/SKILL.md:dispatch_cap` — **perf** (R-5 dispatch cap 자율성 충돌): STOP 직전 cycle 만 무조건, 그 외 2 cycle 마다 1회
- `template/.claude/skills/onboarding/SKILL.md:8번째_질문` — **breaking** (R-6 chat_id 미발급): notify-sender 의 콘솔 fallback + master-spec MISSING 표기
- `template/.claude/skills/phase-intake/SKILL.md:master-spec_읽기` — **side-effect** (R-7 master-spec 너무 길어 token 한계): 길이 cap 권고 (≤50KB) + 1차 요약 후 분해 fallback
- `template/.claude/skills/phase-intake/SKILL.md:idempotency` — **race** (R-8 INTAKE 중복 호출): manifest.total_chunks > 0 면 noop, 재분해는 명시 /ralph-respec
- `template/.claude/skills/review-council/SKILL.md:counter_갱신` — **race** (R-9 counter 동기화 실패): manifest 갱신을 단일 Edit 으로, 매 phase 종료 시 grep 검증
- `template/.claude/commands/ralph-{research,ideation,spec}-done.md` (삭제) — **breaking** (R-10 v1↔v2 슬래시 커맨드): 즉시 삭제. 마이그레이션 가이드에 사용자 책임으로 명시 (docs/v2-rollout-guide.md)

## 3. 롤백 전략

- **Code**: per-task 단일 commit 모드. 문제 발견 시 해당 task 의 commit SHA revert. `git log --oneline | grep "feat(v2):"` 로 task 별 commit 추적
- **State**: `template/.claude/state/intake/` 디렉터리 자체 신설. 롤백 시 `rm -rf` 후 v1 으로 복귀. 기존 하네스 (show-money 등) 의 state 는 영향 없음 (template/ 만 변경)
- **DB**: 본 PRD 는 DB 변경 없음 (template patch only)
- **Config**: `template/.claude/config/notify.md` 신설. 롤백 시 삭제 + ralph-tick 의 notify-sender 호출 단계 무효화
- **호환성**: v1 ↔ v2 동거 보장 X — 새 하네스만 v2 template 으로 eject. 기존 하네스는 v1 template 으로 eject 된 상태 그대로 (이미 자체 git 저장소)

---

## 변경이력

<!-- change-history skill auto-appends entries here, oldest first -->

### [2026-05-10 14:48] [구현계획서-수정]

- **id**: CH-20260510-003
- **이유**: 신규 구현계획서 — ralph-v2-tech-design.md 의 D-1~D-8 결정과 R-1~R-10 위험을 14개 TDD task 로 분해
- **무엇이**: ralph-v2-implementation-plan.md 전체 — §1 Task 1~14 (메타 docs / state schema / ralph-tick / 신규 4 skill / 갱신 6 skill / 폐기 2 skill / 페르소나 15 / 슬래시 커맨드 / verify 스크립트 / rollout 가이드), §2 위험 코드 지점 R-1~R-10 매핑, §3 롤백 전략. commit_policy=per-task.
- **영향범위**: 없음 (최초 생성). verify-spec 22/22 mapped 0 conflicts. code-pretty 1 change (phase flow line wrap), docs-pretty no-op.
- **연관 항목**: CH-20260510-001 (PRD), CH-20260510-002 (tech-design)

### [2026-05-10 15:18] [코드-수정] (batch: tasks 1..14)

- **id**: CH-20260510-004
- **이유**: ralph-v2 factory 재설계 14 task 일괄 구현 (4 wave 병렬 + 메인 후처리)
- **무엇이**: 루트 CLAUDE.md / template/CLAUDE.md / README ×2, template/.claude/state/ralph-status.md + intake/ 신설 (master-spec/manifest/chunks/.gitkeep), template/.claude/skills/ {ralph-tick 재작성, phase-implement+phase-spec 갱신, gate-verify+gap-analysis+project-stop-check+review-council 갱신, onboarding+phase-intake+chunk-detail+notify-sender 신규, phase-research+ideation-council 폐기}, template/.claude/agents/ 15 페르소나 톤 갱신, template/.claude/commands/ {ralph-run+ralph-respec 갱신·신규, ralph-research-done+ralph-ideation-done+ralph-spec-done+ralph-cycle-start 폐기}, template/.claude/config/notify.md 신규, scripts/verify-v2-template.sh 신규, docs/v2-rollout-guide.md 신규
- **영향범위**: 모든 신규 ralph 하네스 (eject 시점 v2 template 적용). 기존 v1 하네스 (show-money/GodMode/PlanB) 는 영향 X (자체 .claude/ 보존)
- **위험 카테고리**: side-effect (R-1/R-2/R-3/R-4/R-7), breaking (R-6/R-10), race (R-8/R-9), perf (R-5)
- **task별 세부 (14건, plan order)**:
  - Task 1: `CLAUDE.md / template/CLAUDE.md / README.md / template/README.md` — 메타 docs (6원칙+대표님-직원+도표) (`side-effect`) — commit: `a19c073`
  - Task 2: `template/.claude/state/ralph-status.md + intake/{master-spec.md, manifest.md, chunks/.gitkeep}` — state schema (`breaking`) — commit: `1b8bde7`
  - Task 7: `template/.claude/skills/notify-sender/SKILL.md + config/notify.md` — Telegram 3시점 (`side-effect`) — commit: `0ce0461`
  - Task 9: `template/.claude/skills/{phase-implement,phase-spec}/SKILL.md` — 플래너 제거 + chunk 상세화 (`side-effect`) — commit: `48872d8`
  - Task 10: `template/.claude/skills/{phase-research,ideation-council}/` — 디렉터리 삭제 (`breaking`) — commit: `686d950`
  - Task 11: `template/.claude/agents/{pm,dev,qa,designer,marketer}/*.md` (15개) — 대표님 톤 + dev 플래너 책임 제거 (`side-effect`) — commit: `0d6e8d3`
  - Task 3: `template/.claude/skills/ralph-tick/SKILL.md` — phase machine 재작성 (`side-effect, breaking`) — commit: `d7eab3d`
  - Task 4: `template/.claude/skills/phase-intake/SKILL.md` — LLM 자동 chunk 분해 (`side-effect`) — commit: `43f2a19`
  - Task 5: `template/.claude/skills/chunk-detail/SKILL.md` — RESEARCH+IDEATION 통합 (`side-effect`) — commit: `2a2165f`
  - Task 6: `template/.claude/skills/onboarding/SKILL.md` — 8 인터뷰 + 동결 (`side-effect`) — commit: `9077c4b`
  - Task 8: `template/.claude/skills/{gate-verify,gap-analysis,project-stop-check,review-council}/SKILL.md` — runtime evidence + master-spec 비교 + chunk 소진 + dispatch cap (`side-effect, perf`) — commit: `913731f`
  - Task 12: `template/.claude/commands/` — 폐기 4 + ralph-run + ralph-respec (`breaking`) — commit: `48601d3`
  - Task 13: `scripts/verify-v2-template.sh` — AC-5 정적 검증 (none) — commit: `2579391`
  - Task 14: `docs/v2-rollout-guide.md` — e2e 검증 + 마이그 안내 (none) — commit: `4497585`
- **연관 commits**: `8170fec..4497585` (14 task commits)
- **변경 전/후 코드**: 생략 — `git show <SHA>` 로 조회
- **연관 항목**: CH-20260510-001 (PRD), CH-20260510-002 (tech-design), CH-20260510-003 (plan)
