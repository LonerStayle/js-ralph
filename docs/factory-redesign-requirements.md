# js-ralph factory 재설계 — 요구사항 목록 (실행 대기)

작성일: 2026-05-10
상태: **합의 완료, 구현 미착수**
다음 세션 작업: 본 문서의 §11 작업 순서대로 한 번에 patch

**선행 문서**
- `docs/redesign-external-master-spec.md` — 외부 master-spec 모델 설계 (어제)
- `~/jinsup_ralph/show-money/docs/lessons/2026-05-09-ralph-self-loop-postmortem.md` — show-money cycle 1~6 사후분석
- `~/jinsup_ralph/show-money/docs/lessons/feedback-to-ralph-factory.md` — 5함정 + factory 개선 제안

---

## 0. 한 줄 요약

기존 ralph 는 "사용자 한 줄 요청 → ralph 가 자기 spec 만들고 자기 채점" 모델이었음. show-money 6 cycle 후 self-referential 함정이 드러남. 이걸 **"대표님이 디테일 기획문서 제공 → 직원(페르소나)들이 그 문서 따라 키움"** 모델로 전면 재설계. 동시에 7원칙 정비 + 흐름 단순화 + 외부 알림.

---

## 1. 변경 #1 — 7원칙에서 "플래너 패턴" 제거

### 배경
- 기존 7원칙 중 #3 = 플래너 패턴 강제 (실행 전 dev 플래너가 step plan 생성)
- 사용자 피드백: **"속도가 너무 느려"**
- 매 IMPLEMENT 마다 플래너가 별도 단계로 끼어드니 cycle 시간이 길어짐

### 변경 내용
- 7원칙 #3 "플래너 패턴" 삭제 → 7원칙 → 6원칙으로 축소 (또는 빈 자리에 다른 원칙 승격)
- dev 페르소나는 그대로 두되, "구현 전 플래너 호출 강제" 메커니즘만 제거
- 각 dev 페르소나가 직접 IMPLEMENT (필요 시 자체 사고 후 바로 코딩)

### 영향 파일
- 루트 `CLAUDE.md` 의 "7원칙 ↔ Claude Code 인프라 매핑" 표 (3번 행 삭제 또는 다른 원칙으로 대체)
- `template/CLAUDE.md` 의 "7대 원칙" 표 (동일)
- `template/.claude/agents/dev/dev-architect.md`, `dev-pragmatist.md`, `dev-security-paranoid.md` 의 "플래너 역할" 명시 부분 제거 (페르소나 자체는 유지, 책임만 간소화)
- `template/.claude/skills/phase-implement/SKILL.md` 의 플래너 사전 호출 단계 제거
- `README.md` 의 "7대 원칙 (요약)" 섹션
- 신규 모델의 onboarding/INTAKE 흐름 문서

### 결정된 선택지
- ☑️ 완전 제거 (옵션 채택)
- ☐ 약화 (선택형 호출) — 거부됨

---

## 2. 변경 #2 — "대표님-직원" 메타포 도입

### 배경
- 기존 정의: "사용자는 개발자, 기획/디자인/마케팅/QA 시야가 모자라서 페르소나 풀로 보완"
- 사용자 새 thesis: **"사용자가 대표님, 페르소나가 직원. 대표님이 방향 정해주면 직원들이 키움"**
- 권한/책임 경계 명확화: 대표님 = 비전 source, 직원 = 실행

### 변경 내용
- 사용자 호칭 = **"대표님"** (페르소나가 사용자에게 발화 시 항상)
- 5역할 페르소나 = **"직원"** (PM/Dev/QA/Designer/Marketer)
- 프로젝트 시작 = 대표님이 디테일 기획문서(=master-spec) 1회 제공
- 이후 = ralph 자율 (직원들이 master-spec 을 키워감)
- 각종 산출물 (council 보고, QA findings, GAP 분석 등) 의 톤 = "대표님께 보고드립니다" 형식

### 영향 파일
- `template/CLAUDE.md` "사용자 동기" 섹션 → "**대표님-직원 구조**" 로 재작성
- 루트 `CLAUDE.md` 동일 섹션
- 15 페르소나 (`template/.claude/agents/{pm,dev,qa,designer,marketer}/*.md`) 의 frontmatter/description 에 "대표님 호칭 + 보고 톤" 명시
- council / QA / GAP 산출물 템플릿 (`.claude/state/cycles/<N>/{council-feedback,qa-findings,gaps}.md` 의 schema) 에 "보고체" 톤 가이드
- master-spec 가이드 (§3.6 참조) 의 톤
- README "사람의 책임" 섹션 → "**대표님의 1회 work = master-spec 작성**"

### 결정된 선택지
- 메타포 채택 확정
- 호칭은 "대표님" 고정 (CEO/사장님 등 변형 거부)

---

## 3. 변경 #3 — 신규 모델 패치 (외부 master-spec + DONE 재정의 + 5함정 강제 장치)

### 배경 — show-money 6 cycle postmortem 의 5함정

show-money repo 가 cycle 1~6 자율 진행 후 STOP 6/6 PASS → PROJECT_DONE 발화. 그러나 사용자 `make up` 직후 발견:

1. 카드 cta_url 이 정부24 메인 같은 generic landing — URL 진위 검증 0
2. RSS 어댑터가 표제 trim 만, 본문 추출/LLM 분류/광고 차단 0
3. 라벨 클릭 시각 피드백 0, 다음 카드 노출 0
4. 개인화 0

원인 = **5가지 구조적 함정**:

| # | 함정 | 본질 |
|---|------|------|
| 1 | STOP 자동 메트릭만 | "agent 자율 검증 가능" → 측정 가능한 것만 KPI 화. Goodhart's law 의 ralph 버전 |
| 2 | council 시야 spec 안 갇힘 | spec 자체가 인프라 약속이면 council 도 인프라만 봄 |
| 3 | fixture-driven test 가 STOP evidence 로 너무 강력 | mock PASS = "충족" 판정. fixture 의미 검증은 ralph 영역 외 |
| 4 | "cycle N+ 이월" 이 가치 task 의 묘지 | 6 cycle 동안 LLM 요약/UX/개인화 한 번도 IMPLEMENT 안 됨 |
| 5 | 페르소나 dispatch 비용 절감 누적 | cycle 4+ 메인 self-synth 로 외부 시야 사라짐 |

### 변경 내용 — 신규 모델 = "외부 master-spec" + "DONE 재정의" + "함정별 강제 장치"

#### 3-1. 외부 master-spec 도입 (함정 1·2 자동 차단)

**핵심**: spec 의 source-of-truth 가 ralph 안 → 밖 (대표님 작성).

- 새 phase **`INTAKE`** 추가 (cycle 시작 전 1회만 실행)
  - 입력: `.claude/state/intake/master-spec.md` (대표님 작성)
  - 처리: chunk N개로 자동 분해
  - 출력: `state/intake/chunks/<i>.md` + `state/intake/manifest.md` (순서/의존성)
  - chunk 정의: 1 chunk = 1 cycle 분량 (acceptance criteria 5~10개 수준)
- RESEARCH/IDEATION 책임 좁힘 (변경 #5 와 통합)
- council 페르소나 입력에 master-spec chunk 가 명시 박힘 → "spec 외부 시야" 자동 보장
- GAP_ANALYSIS 비교 기준 변경: "ralph 가 만든 spec.md vs 산출물" → "**master-spec chunk vs 산출물**"

**함정 차단 효과**
- 함정 1: master-spec acceptance 가 대표님 작성이라 "측정 가능한 것만" 함정 깨짐
- 함정 2: council 입력에 master-spec chunk 명시 박힘 → 외부 시야 자동 보장

#### 3-2. DONE 기준 재정의

- 기존: 자동 검증 가능 메트릭 (카드 ≥30, 어댑터 ≥3 등)
- 신규: **master-spec 의 모든 chunk 수용 + 각 chunk acceptance PASS = PROJECT_DONE**
- master-spec 작성 가이드는 "포괄적 비전 문서" 톤 강화 (DONE 정의가 이걸로 결정되니 대범위 다 담아야)

#### 3-3. 함정별 강제 장치 (3·4·5는 신규 모델만으론 부족)

**함정 3 (fixture PASS) — runtime evidence 필수**
- `gate-verify` 의 `verify-checklist.md` 에 신규 항목: "**runtime evidence 1회 이상**"
  - cycle 종료 직전 실 환경 발화 결과 캡처 → `cycles/<N>/runtime-evidence.md`
  - 자동 (docker compose up + curl 결과) 또는 사람 sample (cta_url 클릭 결과 첨부)
- 이게 없으면 CHECKLIST FAIL

**함정 4 (이월 묘지) — 이월 cap**
- ralph-tick 절차에 신규 룰: "**같은 항목이 ≥3 cycle 이월되면 STUCK 또는 강제 흡수**"
  - 매 cycle GAP_ANALYSIS / council 결과에서 "cycle N+ 이월" 표기 시 manifest.md 에 카운트
  - 카운트 ≥3 → 다음 cycle 의 chunk 에 강제 합류 또는 STUCK 진입 → 대표님 알림 (변경 #7)

**함정 5 (dispatch 절감) — dispatch 최소 cap**
- council 페르소나 dispatch 가 메인 self-synth 로 대체 가능한 횟수에 cap:
  - **최소 2 cycle 마다 1회는 진짜 페르소나 dispatch 필수**
  - **STOP 도달 직전 cycle (= 마지막 chunk) 은 무조건 dispatch**
- dispatch 카운트는 manifest.md 에 기록

### 영향 파일
- `template/CLAUDE.md` "도메인" 섹션 → "**대표님 master-spec — onboarding 가이드**" (변경 #8 와 통합)
- `template/.claude/skills/phase-intake/SKILL.md` (신규)
- `template/.claude/skills/ralph-tick/SKILL.md` 의 phase 디스패치 표에 INTAKE 추가, NOT_STARTED 동작 정의 (변경 #8)
- `template/.claude/skills/phase-research/SKILL.md`, `phase-spec/SKILL.md` 의 프롬프트 갱신 — master-spec chunk 외 항목 추가 금지 명시 (변경 #5 와 통합)
- `template/.claude/skills/gate-verify/SKILL.md` 에 drift detection + runtime evidence 항목
- `template/.claude/skills/gap-analysis/SKILL.md` 비교 기준을 master-spec chunk 로 교체
- `template/.claude/skills/project-stop-check/SKILL.md` 의 STOP 조건 → chunk 소진 + acceptance PASS
- `template/.claude/skills/review-council/SKILL.md` 에 dispatch 최소 cap 룰
- `template/.claude/state/intake/` 디렉터리 + 빈 `master-spec.md` placeholder
- `template/.claude/config/verify-checklist.md` 에 runtime evidence 항목 표기

### 결정된 선택지
- ☑️ 신규 모델 패치 (확정)
- ☑️ 함정 3·4·5 추가 강제 장치도 함께 (확정 — "이것도" 답변)

### 결정 안 된 (실행 시 정해야 할) 디테일
- chunk 분해 알고리즘: LLM 기반 분류 vs 사람이 master-spec 에 chunk 표시 → **둘 다 지원** (사람 표시 우선, 없으면 LLM)
- runtime evidence 자동화 방식: docker-compose / curl / playwright 어디까지 자동화? → master-spec 도메인 별로 다르므로 가이드만 제공, 구체 명령은 도메인 작성

---

## 4. 변경 #4 — FIXING_* phase 4개 모두 제거

### 배경
- 기존 phase 정의: `QA_REVIEW ↔ FIXING_QA`, `REVIEW_COUNCIL ↔ FIXING_COUNCIL`, `GAP_ANALYSIS ↔ FIXING_GAP`, `CHECKLIST ↔ FIXING_CHECK`
- 4개의 FIXING_* state 가 실질적으로 IMPLEMENT 와 동일 (수정 작업 = IMPLEMENT)
- 분리해두니 phase 디스패치 표가 비대, 상태 머신 복잡

### 변경 내용
- FIXING_* 4개 phase 모두 삭제
- 각 검증 phase 의 FAIL 시 동작: **바로 `IMPLEMENT` 로 직회귀** (별도 phase 진입 없음)
- ralph-status.md 의 phase 정의 표에서 FIXING_* 행 제거

### 영향 파일
- `template/.claude/skills/ralph-tick/SKILL.md` phase 디스패치 표
- `template/.claude/state/ralph-status.md` phase 정의 표
- `template/CLAUDE.md` 루프 구조 도표
- 루트 `CLAUDE.md` 루프 구조 도표

### 결정된 선택지
- ☑️ 4개 모두 제거 (일관성)
- ☐ QA 만 제거 — 거부됨

---

## 5. 변경 #5 — RESEARCH + IDEATION → CHUNK_DETAIL 통합

### 배경
- 신규 모델 (master-spec) 에선 RESEARCH/IDEATION 둘 다 "새 가치 발굴 금지"
- 사실상 같은 일 — 외부 chunk 의 디테일을 채우는 것
- 분리하면 council/페르소나 dispatch 도 2회로 늘어 시간/비용 낭비

### 변경 내용
- RESEARCH, IDEATION → **`CHUNK_DETAIL`** 단일 phase 로 통합
- 책임: 이번 cycle chunk 의 구현 방안 후보 + 디테일 발산을 한 번에 처리
- council/페르소나 dispatch 1회 (변경 #3-3 dispatch 최소 cap 적용)

### 영향 파일
- `template/.claude/skills/ralph-tick/SKILL.md` phase 디스패치 표
- `template/.claude/skills/phase-research/`, `template/.claude/skills/ideation-council/` → `template/.claude/skills/chunk-detail/` 로 통합 (또는 phase-research 흡수)
- `template/.claude/state/ralph-status.md` phase 정의 표
- 슬래시 커맨드: `/ralph-research-done`, `/ralph-ideation-done` → `/ralph-chunk-detail-done` 으로 통합 (또는 둘 다 자율 모드에서 사라짐)
- 루프 구조 도표 (양쪽 CLAUDE.md, README)

### 결정된 선택지
- ☑️ A1: 통합 (속도 ↑, dispatch 1회)
- ☐ A2: 유지 (다양성 ↑, 느림) — 거부됨

---

## 6. 변경 #6 — IMPLEMENT_PENDING_FREEZE 제거

### 배경
- 기존 의미: ralph 가 만든 spec.md 를 사람이 동결 인가하는 게이트 (auto-freeze.flag 면 자동)
- 신규 모델: master-spec 자체가 외부 동결본 → 이 게이트가 의미 잃음
- master-spec INTAKE 동결이 곧 frozen spec source 역할

### 변경 내용
- `IMPLEMENT_PENDING_FREEZE` phase 자체 제거
- SPEC → IMPLEMENT 직진
- `spec-frozen.flag`, `spec-auto-freeze.flag` 메커니즘 폐기 (master-spec 동결로 대체)
- `/ralph-spec-done` 커맨드 → `/ralph-respec` (master-spec 갱신용) 으로 의미 재정의 또는 폐기

### 영향 파일
- `template/.claude/skills/ralph-tick/SKILL.md` phase 디스패치
- `template/.claude/state/ralph-status.md` phase 정의 표
- `template/.claude/commands/ralph-spec-done.md` (폐기 또는 ralph-respec 으로 변경)
- `template/CLAUDE.md` 운영 가정 섹션 (사람 강제 인가 지점 = master-spec 동결 1회 로 재정의)
- 루트 `CLAUDE.md` 같은 섹션
- README 빠른 시작 5단계 → 단순화

### 결정된 선택지
- ☑️ B1: 완전 제거 (master-spec 이 곧 frozen)
- ☐ B2: 유지 + 항상 auto-freeze — 거부됨

---

## 7. 변경 #7 — 외부 알림 (3 시점)

### 배경
- 신규 모델에서 사람 = 대표님 (메타포). ralph 가 자율 진행해도 대표님이 진척/완료/막힘을 알아야 함
- 매 cycle 끝날 때마다 직접 들어가서 ralph-status.md 보는 건 비효율
- 외부 채널 (Gmail / Slack / Telegram) 로 능동 알림

### 변경 내용
3 시점에 외부 알림 발사:

| 시점 | 메시지 |
|------|--------|
| **CYCLE_DONE** | 이번 cycle 진척 보고 — 어떤 chunk 완료 / 다음 chunk / 누적 통계 |
| **PROJECT_DONE** | 완료 보고 — 모든 chunk 소진, 대표님이 띄워보고 사인 요청 |
| **STUCK** (이월 ≥3 cycle 또는 fail_streak ≥5) | 개입 요청 — 어떤 항목이 막혔고 무엇을 결정해줘야 하는지 |

### 영향 파일
- `template/.claude/hooks/notify.sh` (신규) — 채널 dispatch wrapper
- `template/.claude/config/notify.md` (신규) — 대표님 채널 설정 (이메일/slack URL/telegram chat_id)
- `template/.claude/skills/project-stop-check/SKILL.md` 마지막 단계에서 알림 호출
- `template/.claude/skills/ralph-tick/SKILL.md` 에 CYCLE_DONE / STUCK 진입 시 알림 호출
- `template/.claude/settings.json` 의 hooks 영역 (선택 — 자동 발화하려면)

### 결정된 선택지
- ☑️ C2 + C3: CYCLE_DONE + PROJECT_DONE + STUCK 3 시점
- ☐ C1: PROJECT_DONE 만 — 거부됨

### 결정 안 된 (실행 시 정해야 할) 디테일
- 채널 우선순위: Gmail (MCP 있음) / Telegram (MCP 있었으나 disconnected) / Slack (별도 webhook 필요)
- → **Gmail MCP 우선** 권장 (이미 connected, draft 만 만들고 send 는 별도 인가)
- 알림 내용 템플릿 — `notify.md` 에 message format 정의

---

## 8. 변경 #8 — eject 후 진입점 = 대표님 onboarding 대화

### 배경
- 기존 흐름: eject → 사용자가 CLAUDE.md 도메인 섹션 + verify-checklist + deploy.sh 직접 편집 → /ralph-deploy → /ralph-cycle-start
- 사람이 편집할 게 너무 많음. 사용자 thesis: **"eject 후 그냥 claude 세션 들어가면 ralph 가 알아서 대표님께 인사하고 지시사항 받기"**

### 변경 내용

#### 진입 흐름
```
new-harness.sh (eject) → cd ~/jinsup_ralph/<name>
   ↓
claude     # 새 세션
   ↓
ralph 가 즉시: "대표님 안녕하십니까. 이 프로젝트의 비전과 지시사항을 주십시오."
   ↓
대표님이 대화로 비전/큰 방향 제공 → ralph 가 master-spec.md 초안 작성
   ↓
대표님 "확정" → state/intake/master-spec.md 동결 → INTAKE phase 자동 전이 → cycle 시작
```

#### 트리거 메커니즘
- `ralph-tick` 의 **`NOT_STARTED`** phase 동작 정의:
  - master-spec.md 존재 + 동결 → INTAKE 자동 전이
  - master-spec.md 비어 있거나 미동결 → **onboarding 모드**
- onboarding 모드 = 새 스킬 `onboarding/SKILL.md` 호출
- `claude` 세션 시작 시 자동으로 ralph-tick 1회 발화 (또는 ralph-loop 즉시 시작)

### 영향 파일
- `template/CLAUDE.md` 의 "도메인" 섹션 → **"대표님 지시사항 — onboarding 가이드"** 로 교체
  - 첫 진입 시 ralph 가 무엇을 묻는지 (질문 템플릿)
  - master-spec 작성 가이드 (포괄적 비전 문서, §3.6 참조)
  - 동결 절차 (대표님이 "확정" 발화 시 master-spec.md 잠금)
- `template/.claude/skills/onboarding/SKILL.md` (신규)
  - 대표님 인터뷰 5~10 질문 (도메인/입력/산출물/사용자/성공 정의/금지/외부 의존/규모/일정/제약)
  - 답변 → master-spec.md 초안 합성
  - 대표님 review 요청 → 동결 시 lock
- `template/.claude/skills/ralph-tick/SKILL.md` 의 NOT_STARTED phase 동작
- `template/.claude/state/intake/master-spec.md` placeholder 비움 (onboarding 으로 채우도록)
- `scripts/new-harness.sh` 의 next-step 안내 단순화: "claude 세션 들어가면 알아서 대표님께 인사" 만
- `README.md` 의 빠른 시작 갱신:
  - 도메인 채우기 단계 사라짐
  - eject → claude → 대화 → /ralph-run (또는 onboarding 후 자동 시작)
- `template/.claude/settings.json` — SessionStart hook 으로 ralph-tick 자동 발화 (선택)

### 결정된 선택지
- 채택 확정
- 호칭 = "대표님" (변경 #2 와 일관)

### 결정 안 된 (실행 시 정해야 할) 디테일
- onboarding 인터뷰 질문 갯수: 5 / 8 / 10 (대표님 피로도 vs master-spec 충실도) → 8 권장
- master-spec 동결 트리거: "확정" 키워드 / 명시 슬래시 (`/ralph-spec-confirm`) / 둘 다 지원
- 인터뷰 결과 부족 시 ralph 가 추가 질문 던지기 vs 그대로 chunk 분해 진행 → 추가 질문 (대표님 부담 적게, 2~3 round 까지만)

---

## 9. 최종 흐름 도표

```
[1회 — 사람]
대표님 → claude 세션 시작
   ↓
[1회 — onboarding (변경 #8)]
ralph: "대표님 안녕하십니까, 비전을 주십시오"
   ↓ 대화 인터뷰 5~10 질문
ralph: master-spec.md 초안 작성 → 대표님 review → 동결
   ↓

[1회 — INTAKE phase (변경 #3-1)]
ralph: master-spec → chunk N개 분해 → manifest.md
   ↓

[각 cycle 반복 — chunk 1개당]
   CHUNK_DETAIL    (변경 #5: RESEARCH+IDEATION 통합)
      ↓ gate-verify (drift detection)
   SPEC            (chunk 상세화)
      ↓ gate-verify
                   ※ IMPLEMENT_PENDING_FREEZE 제거 (변경 #6)
   IMPLEMENT       (변경 #1: 플래너 없음, dev 페르소나 직접)
      ↓
   QA_REVIEW       FAIL → IMPLEMENT 직회귀  (변경 #4: FIXING_QA 제거)
      ↓ clean
   REVIEW_COUNCIL  FAIL → IMPLEMENT 직회귀  (변경 #4 + #3-3 dispatch 최소 cap)
      ↓ PASS
   GAP_ANALYSIS    FAIL → IMPLEMENT 직회귀  (변경 #3-1: master-spec chunk vs 산출물)
      ↓ no gaps
   CHECKLIST       FAIL → IMPLEMENT 직회귀  (변경 #3-3: runtime evidence 포함)
      ↓ PASS
   CYCLE_DONE → 외부 알림 (변경 #7: 진척 보고)
      ↓
   project-stop-check
      ├ chunks 모두 소진 + acceptance PASS → PROJECT_DONE → 외부 알림 (완료 보고)
      └ 미달 → 다음 chunk 로 진입
   
   ※ 같은 항목 ≥3 cycle 이월 시 STUCK → 외부 알림 (개입 요청, 변경 #7)
```

---

## 10. phase 정의 비교 표

| 기존 phase | 신규 phase | 비고 |
|-----------|-----------|------|
| NOT_STARTED | NOT_STARTED | onboarding 모드로 동작 정의 (변경 #8) |
| (없음) | **INTAKE** | 신규 (변경 #3-1) |
| RESEARCH | **CHUNK_DETAIL** | RESEARCH+IDEATION 통합 (변경 #5) |
| IDEATION | (CHUNK_DETAIL 에 흡수) | |
| SPEC | SPEC | chunk 상세화로 의미 좁힘 |
| IMPLEMENT_PENDING_FREEZE | ~~제거~~ | (변경 #6) |
| IMPLEMENT | IMPLEMENT | 플래너 사전 호출 제거 (변경 #1) |
| QA_REVIEW ↔ FIXING_QA | QA_REVIEW (FAIL → IMPLEMENT) | (변경 #4) |
| REVIEW_COUNCIL ↔ FIXING_COUNCIL | REVIEW_COUNCIL (FAIL → IMPLEMENT) | dispatch 최소 cap (변경 #3-3) |
| GAP_ANALYSIS ↔ FIXING_GAP | GAP_ANALYSIS (FAIL → IMPLEMENT) | master-spec 비교 기준 (변경 #3-1) |
| CHECKLIST ↔ FIXING_CHECK | CHECKLIST (FAIL → IMPLEMENT) | runtime evidence 추가 (변경 #3-3) |
| CYCLE_DONE | CYCLE_DONE + 외부 알림 | (변경 #7) |
| PROJECT_DONE | PROJECT_DONE + 외부 알림 | (변경 #7) |
| STUCK_<phase> | STUCK_<phase> + 외부 알림 | 이월 cap 트리거 추가 (변경 #3-3, #7) |

---

## 11. 한꺼번에 실행 시 작업 순서 (다음 세션)

다음 순서대로 patch 진행. 각 단계마다 git commit 권장 (rollback 단순화).

### 단계 A. 메타 (CLAUDE.md / README)
1. 루트 `CLAUDE.md` 7원칙 표 갱신 (플래너 제거 #1, 대표님-직원 #2, 루프 구조 도표 신규)
2. `template/CLAUDE.md` 자가완결본 전면 재작성 (도메인 → onboarding 가이드, 운영 가정 → 대표님 모델)
3. `README.md` 빠른 시작 단순화 (도메인 채우기 단계 제거)

### 단계 B. phase 정의 (skills + state)
4. `template/.claude/skills/ralph-tick/SKILL.md` phase 디스패치 표 전면 갱신
5. `template/.claude/state/ralph-status.md` phase 정의 표 갱신
6. `template/.claude/state/intake/` 디렉터리 + placeholder

### 단계 C. 신규 스킬
7. `template/.claude/skills/onboarding/SKILL.md` 신규
8. `template/.claude/skills/phase-intake/SKILL.md` 신규
9. `template/.claude/skills/chunk-detail/SKILL.md` 신규 (또는 phase-research 흡수)

### 단계 D. 기존 스킬 갱신
10. `template/.claude/skills/gate-verify/SKILL.md` — drift detection + runtime evidence
11. `template/.claude/skills/gap-analysis/SKILL.md` — master-spec chunk 비교
12. `template/.claude/skills/project-stop-check/SKILL.md` — chunk 소진 + acceptance PASS 로 STOP
13. `template/.claude/skills/review-council/SKILL.md` — dispatch 최소 cap
14. `template/.claude/skills/phase-implement/SKILL.md` — 플래너 호출 제거
15. `template/.claude/skills/phase-spec/SKILL.md` — chunk 상세화로 의미 좁힘
16. `template/.claude/skills/phase-research/`, `ideation-council/` — chunk-detail 로 통합 또는 폐기

### 단계 E. 페르소나 (15개)
17. `template/.claude/agents/{pm,dev,qa,designer,marketer}/*.md` — 직원 톤 + 대표님 호칭
18. dev/* 페르소나에서 플래너 책임 제거

### 단계 F. 슬래시 커맨드
19. `template/.claude/commands/ralph-research-done.md`, `ralph-ideation-done.md` — 폐기 또는 ralph-chunk-detail-done 으로 통합
20. `template/.claude/commands/ralph-spec-done.md` — 폐기 또는 ralph-respec 으로 의미 변경
21. `template/.claude/commands/ralph-run.md` — onboarding 자동 진입 반영

### 단계 G. 외부 알림 / 기타
22. `template/.claude/hooks/notify.sh` 신규
23. `template/.claude/config/notify.md` 신규 (대표님 채널 설정 placeholder)
24. `template/.claude/config/verify-checklist.md` 에 runtime evidence 항목

### 단계 H. 스캐폴딩
25. `scripts/new-harness.sh` next-step 안내 단순화

### 단계 I. 검증
26. 새 하네스 1개 eject → claude 세션 → onboarding 정상 발화 확인
27. 기존 GodMode / PlanB / show-money 마이그레이션 가이드 작성 (선택)

---

## 12. 미해결 질문 (다음 세션 시작 시 결정)

1. chunk 분해 알고리즘 — LLM vs 사람 표시 vs 둘 다 → **둘 다 지원, 사람 표시 우선** 권장
2. runtime evidence 자동화 범위 — 도메인별 다르므로 가이드만, 명령은 도메인 책임
3. onboarding 인터뷰 질문 수 — 5/8/10 → **8** 권장
4. master-spec 동결 트리거 — 키워드 vs 슬래시 vs 둘 다 → **둘 다**
5. 외부 알림 채널 우선순위 — Gmail MCP 우선, Slack/Telegram fallback
6. 7원칙 → 6원칙 축소 vs 다른 원칙 승격 → 6원칙 깔끔, 또는 "외부 master-spec source-of-truth" 를 신규 원칙 #3 자리에 넣기

---

## 13. show-money 마이그레이션 (선택, 사용자 판단)

- show-money 는 cycle 6 PROJECT_DONE 상태
- 신규 모델로 갈아탈 경우:
  1. 사용자 (대표님) 가 master-spec.md 작성 — postmortem §6.2 의 priority 1~4 (LLM 파이프라인 / 도메인 좁히기 / 인터랙션 / STOP 재정의) 를 chunk 로 풀어서 작성
  2. 기존 spec-auto-freeze.flag 폐기 (master-spec 동결로 대체)
  3. ralph-status.md 의 phase 표 갱신
  4. INTAKE 호출 → 새 cycle 진입
- 갈아타지 않을 경우: factory template 만 갱신, show-money 는 그대로 보존

---

## 14. 이 문서의 다음 사용처

- 다음 세션 시작 시 본 문서 §11 작업 순서대로 patch 진행
- 작업 중 막히면 §12 미해결 질문 답하면서 결정
- 작업 완료 후 본 문서를 `archive/` 또는 `docs/done/` 으로 이동, 또는 PR description 으로 흡수

---

_End. 작성 시점 합의 = 8개 변경 + 13개 미해결 디테일 (§12 6개 + 본문 산재). 작업 추정 = 1~2 세션 (~2~4시간 maker time + 검증)._
