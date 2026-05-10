# 요구사항: ralph-v2

> **Mode:** Socratic (free-form prose). Downstream `designing-direction` reads this without expecting fixed PRD section IDs.
>
> **선행 자료**:
> - `docs/factory-redesign-requirements.md` — 8개 변경 + 13 미해결 디테일 + 27 작업 단계
> - `docs/redesign-external-master-spec.md` — 외부 master-spec 모델 설계 (2026-05-09)
> - `~/jinsup_ralph/show-money/docs/lessons/{postmortem, feedback-to-ralph-factory}.md` — show-money 6 cycle 사후분석 + 5함정

---

## 1. 배경 / 동기

### 1.1 무엇을 재설계하는가

js-ralph factory 의 **template + 운영 모델 전체**를 v2 로 갈아엎는다. 새 하네스가 eject 됐을 때 적용되는 7원칙 / 페르소나 / 페이즈 / 슬래시 커맨드 / hooks / state 가 전부 영향 받음.

### 1.2 왜 — show-money 가 증명한 v1 의 함정

show-money 가 6 cycle 자율 진행 후 STOP 6/6 PASS → PROJECT_DONE 발화. 그러나 사용자 `make up` 직후:

- 카드 cta_url 이 generic landing (URL 진위 0)
- RSS 어댑터가 표제 trim 만 (본문 추출 / LLM 분류 / 광고 차단 0)
- 라벨 클릭 시각 피드백 0, 다음 카드 노출 0
- 개인화 0

원인 = **5가지 self-referential 함정** (postmortem 출처):

| # | 함정 | 본질 |
|---|------|------|
| 1 | STOP 자동 메트릭만 | "agent 자율 검증 가능" → 측정 가능한 것만 KPI 화 (Goodhart's law) |
| 2 | council 시야 spec 안 갇힘 | spec 자체가 인프라 약속이면 council 도 인프라만 봄 |
| 3 | fixture-driven test 가 STOP evidence 로 너무 강력 | mock PASS = "충족" |
| 4 | "cycle N+ 이월" 이 가치 task 의 묘지 | LLM 요약/UX/개인화 한 번도 IMPLEMENT 안 됨 |
| 5 | 페르소나 dispatch 비용 절감 누적 | 외부 시야 점진 소실 |

**핵심 한 줄**: "사용자 1번 클릭 = ralph 6 cycle 보다 강력한 quality gate"

### 1.3 v2 의 정체성 — 100% 자율 + 양 끝(시작/마지막)만 사람

- **시작**: 대표님이 master-spec 작성 + 동결 (1회)
- **중간**: ralph 100% 자율. 사람 게이트 0. 외부 알림으로만 진척 통보
- **마지막**: PROJECT_DONE 알림 받고 대표님이 검토 (1회)
- **예외**: STUCK 발생 시 Telegram 알림 + 대표님 응답 가능 (인터랙티브) — 하지만 응답 없어도 ralph 는 다른 chunk 우회 진행

이 모델은 show-money 의 "사용자 1번 클릭" 교훈을 **양 끝에 압축** 하면서도 자율성을 잃지 않게 화해시키려는 설계 결정이다.

---

## 2. 핵심 결정 (Socratic 합의 사항)

### 2.1 7원칙 → 6원칙 축소 (Q1)

**플래너 패턴 (#3) 완전 제거**. 속도 저하 이유. dev 페르소나는 보존되되 "구현 전 플래너 호출 강제" 메커니즘만 삭제. 6원칙으로 단순 축소 (다른 원칙 승격 / 신규 원칙 박기 X).

### 2.2 LLM 자동 chunk 분해 (Q2)

대표님이 master-spec.md 를 자유 prose 로 작성 → ralph 가 INTAKE phase 에서 LLM 자동 분해. 사람이 chunk 마커 표시할 의무 없음. 분해 결과 review 게이트 없음 (Q3 와 일관).

### 2.3 100% 자율 + 끝-검토 (Q3)

분해 결과도 자동 통과. 매 cycle gate 마다 사람 sign-off 도 없음. 대표님은 PROJECT_DONE 시점에 한 번 검토.

### 2.4 Telegram 인터랙티브 + 대표님 톤 보고서 (Q4)

- **채널**: Telegram MCP 단일 채널
- **인터랙티브**: 대표님이 직접 응답 가능 (STUCK 해결, 방향 코멘트 등)
- **톤**: 비기술 언어, 대표님이 실무 상세 모름 가정. "기획은 이렇게 결정됐고, 개발은 이렇게 됐고, 다음은 이런 방향" 식 정갈한 보고서
- **시점 3종**: CYCLE_DONE 진척 / PROJECT_DONE 완료 / STUCK 개입 요청

### 2.5 STUCK 시 보류 후 우회 (Q5)

STUCK chunk 는 manifest 에 `BLOCKED` 표기 + Telegram 알림 발사. ralph 는 그 chunk 를 건너뛰고 manifest 의 다음 가용 chunk 진행. 마지막에 대표님이 BLOCKED chunk 까지 한 번에 검토.

### 2.6 v2 자체 수용 기준 = end-to-end 자율 1회 (Q6)

factory patch + 신규 하네스 1개 eject → onboarding 인터뷰 → master-spec 동결 → INTAKE chunk 분해 → cycle 1 의 chunk 1 자율 완주 (코드까지) → CYCLE_DONE 알림 발사. 이 흐름이 end-to-end 한 번 통과해야 v2 PROJECT_DONE.

---

## 3. 사용자 시나리오 (대표님 흐름)

### 3.1 골든 패스

```
[Day 0]
대표님 → ` cd ~/jinsup_ralph/<new-name> && claude `
   ↓
ralph: "대표님 안녕하십니까. 이 프로젝트의 비전과 지시사항을 주십시오."
   ↓
대표님 → 비전/방향 대화 (8 정도 질문 응답)
   ↓
ralph → master-spec.md 초안 작성 → 대표님 review → "확정" 발화 → 동결
   ↓
ralph → INTAKE: chunk N개 분해 → 자율 cycle 시작

[Day 1~N — 대표님 무관]
ralph: 매 CYCLE_DONE 시 Telegram 진척 보고
   "📊 사이클 3 완료
    기획: 정부24 어댑터 추가 결정 (이유: 콘텐츠 다양성)
    개발: 본문 추출 + URL 진위 검증 모듈 추가 완료
    다음 사이클: 사용자 라벨 시각 피드백 작업"
   ↓
   (필요시) STUCK 발생 → Telegram 알림 + 대표님 응답 옵션
   "⚠️ 막힘 발생 (chunk 4: '개인화 추천')
    이유: master-spec 의 '관심 카테고리 가중치' 가 모호. 일단 보류하고 다음 chunk 로 진행 중.
    필요 시 한 줄 답변 주세요. 답이 없어도 마지막에 정리해 드립니다."

[Day N+1 — PROJECT_DONE]
ralph: Telegram 으로 PROJECT_DONE 알림 + Gmail 보고서 X (Telegram only)
   "🎉 프로젝트 완료
    완료된 chunk: 8 / 보류된 chunk: 2
    띄워보시고 검토 부탁드립니다: docker compose up
    보류 항목: chunk 4 ('개인화 추천'), chunk 7 ('알림 OAuth')
    상세는 docs/runtime-evidence.md / state/cycles/*"
   ↓
대표님 → 직접 띄워서 결과 검증 → 사인 또는 master-spec 갱신 후 재시작
```

### 3.2 사용자 발화 횟수 (정량)

| 시점 | 발화 |
|------|------|
| 0. master-spec onboarding 인터뷰 | ~8 답변 |
| 1. master-spec 초안 동결 | 1 |
| 2. (선택) STUCK 응답 | 0~N (skip 가능) |
| 3. PROJECT_DONE 검토 사인 | 1 |
| **총** | **최소 10 / 평균 10~15** |

(v1 = SPEC 동결 N회 + 매 cycle 게이트 N회 = 사실상 manual 모델로 회귀하기 쉬움. v2 = 양 끝에 압축)

---

## 4. 기능 요구사항 (FR)

### FR-1. 7원칙 → 6원칙 축소

- 플래너 패턴 (#3) 완전 제거
- 루트 `CLAUDE.md`, `template/CLAUDE.md`, `README.md` 의 7원칙 매핑 표를 6원칙으로 갱신
- dev 페르소나에서 플래너 책임 명시 제거 (페르소나 자체는 유지)
- 슬래시 커맨드 / 스킬에서 플래너 사전 호출 단계 제거

### FR-2. 대표님-직원 메타포 도입

- 사용자 호칭 = "대표님"
- 5역할 페르소나 = "직원"
- 페르소나 정의 frontmatter / description 에 호칭 + 보고 톤 명시
- 모든 산출물 (council / QA / GAP / 알림) 의 톤 = 대표님께 보고드리는 형식

### FR-3. 외부 master-spec 모델 도입

- 새 phase **`INTAKE`** 추가 (cycle 시작 전 1회만)
- 입력: `.claude/state/intake/master-spec.md` (대표님 작성, prose)
- 처리: LLM 자동 chunk 분해 (사람 마커 의무 없음)
- 출력: `state/intake/chunks/<i>.md` + `state/intake/manifest.md` (순서/의존성/상태)
- chunk 정의: 1 chunk = 1 cycle 분량 (acceptance 5~10개)
- 분해 결과 review 게이트 X — 자동 통과
- council / GAP / CHECKLIST 입력에 master-spec chunk 명시 박힘 (외부 시야 보장)

### FR-4. DONE 기준 재정의

- 기존: 자동 검증 가능 메트릭 (카드 ≥30 등)
- 신규: master-spec 모든 chunk 수용 + 각 chunk acceptance PASS = PROJECT_DONE
- master-spec 작성 가이드는 "포괄적 비전 문서" 톤 강화

### FR-5. 함정 3·4·5 강제 장치

- **함정 3 (fixture PASS)**: gate-verify 의 verify-checklist 에 "**runtime evidence 1회 이상**" 항목. cycles/<N>/runtime-evidence.md 미작성 시 CHECKLIST FAIL
- **함정 4 (이월 묘지)**: 같은 항목이 ≥3 cycle 이월되면 BLOCKED 표기 + Telegram 알림 (단 ralph 는 다음 chunk 진행)
- **함정 5 (dispatch 절감)**: council 페르소나 dispatch 가 메인 self-synth 로 대체 가능한 횟수 cap. **최소 2 cycle 마다 1회 진짜 dispatch / STOP 직전 cycle 무조건 dispatch**

### FR-6. FIXING_* phase 4개 모두 제거

- FIXING_QA / FIXING_COUNCIL / FIXING_GAP / FIXING_CHECK 삭제
- FAIL 시 바로 IMPLEMENT 직회귀 (별도 phase 진입 X)

### FR-7. RESEARCH + IDEATION → CHUNK_DETAIL 통합

- 단일 phase `CHUNK_DETAIL` 로 통합
- 책임: chunk 의 구현 방안 후보 + 디테일 발산을 한 번에
- 페르소나 dispatch 1회 (FR-5 의 dispatch 최소 cap 적용)

### FR-8. IMPLEMENT_PENDING_FREEZE phase 제거

- master-spec 자체가 외부 동결본 → 이 게이트 의미 잃음
- SPEC → IMPLEMENT 직진
- `spec-frozen.flag` / `spec-auto-freeze.flag` 메커니즘 폐기
- `/ralph-spec-done` 커맨드 폐기 또는 `/ralph-respec` (master-spec 갱신용) 으로 의미 변경

### FR-9. Telegram 인터랙티브 외부 알림 (3 시점)

- **CYCLE_DONE**: 진척 보고 메시지 (기획/개발/다음 방향, 비기술 톤)
- **PROJECT_DONE**: 완료 보고 (완료/보류 chunk 수 + 검증 명령 안내)
- **STUCK**: 개입 요청 (보류 이유 + 대표님 한 줄 답 옵션, 응답 없어도 진행)
- 메시지 템플릿: 비기술 언어, "기획 / 개발 / 결정" 분리 보고
- 대표님이 Telegram reply 로 답변 시 ralph 가 다음 tick 에서 읽고 반영

### FR-10. eject 후 onboarding 대화 진입점

- `claude` 세션 시작 시 ralph 가 즉시 "대표님 안녕하십니까. 비전을 주십시오"
- ralph-tick 의 NOT_STARTED phase 동작:
  - master-spec.md 비어 있거나 미동결 → onboarding 모드 진입
  - master-spec.md 동결 → INTAKE 자동 전이
- 신규 스킬 `onboarding/SKILL.md`: ~8 질문 인터뷰 → master-spec 초안 합성 → "확정" 발화로 동결

### FR-11. STUCK 시 chunk 보류 + 우회 진행

- STUCK chunk 는 manifest 에 `BLOCKED` 표기
- ralph 는 다음 chunk 로 진행 (자율 멈춤 X)
- PROJECT_DONE 시점에 BLOCKED chunk 들도 보고에 포함 (대표님이 한 번에 검토)

---

## 5. 비기능 / 운영 요구사항

### NFR-1. 자율도

- 사람 발화 횟수 ≤ 15회 / 1 프로젝트 (시작 onboarding ~8 + 동결 1 + STUCK 0~N + 종료 검토 1)
- 매 cycle 의 사람 게이트 = 0
- 분해 / SPEC 동결 / FIXING / CYCLE_DONE 사인 모두 자동

### NFR-2. 외부 알림 톤

- 비기술 언어 (jargon 사용 시 1줄 풀어서 설명)
- 메시지 schema = 기획 결정 / 개발 산출 / 다음 방향 3 부분 분리
- 메시지 길이: Telegram 한 화면 (≈ 3~5줄 핵심) + (선택) 상세는 링크 / 첨부

### NFR-3. STUCK 응답 SLA 없음

- 대표님 응답이 며칠 늦어도 ralph 는 다른 chunk 로 진행
- STUCK chunk 는 무한 대기 (max-iterations 300 cap 내에서)

### NFR-4. master-spec 작성 부담

- prose 자유 작성 (chunk 마커 의무 X)
- 인터뷰 형식으로 ralph 가 대표님에게 질문해서 작성 가능
- 가이드: 포괄적 비전 (도메인 / 입력 / 산출물 / 사용자 / 성공 정의 / 금지 / 외부 의존 / 규모)

### NFR-5. 호환성

- ralph-loop 플러그인 위에서 동작 (기존 가정 유지)
- Stop hook 기반 self-referential 루프 메커니즘 변경 X
- `${CLAUDE_PROJECT_DIR}` 절대경로 hooks 유지 (이전 fix)

### NFR-6. 검증 수용 기준

- 신규 하네스 1개를 실제로 eject → onboarding → INTAKE → cycle 1 chunk 1 코드까지 자율 완주
- CYCLE_DONE Telegram 알림 1회 도달
- 이 흐름이 통과해야 v2 PROJECT_DONE

---

## 6. 범위 밖 (Out of Scope)

다음은 v2 PRD 안에 포함하지 않음 — 별도 결정 / 추후 작업 / 운영 단계로 미룸:

1. **show-money 마이그레이션** — show-money 는 cycle 6 PROJECT_DONE 상태. 신규 모델로 갈아타려면 본질적으로 새 master-spec 작성 = 새 프로젝트. 마이그레이션은 사용자가 별도 결정 시 별도 작업으로
2. **factory 의 sync-from-factory 스크립트** — template 갱신을 기존 eject 된 하네스로 자동 동기화. 미루어 둠 ("필요해지면 그때")
3. **Gmail 보고서 채널** — Q4 에서 Telegram 단일 결정. Gmail 은 추후
4. **Slack / 기타 메신저 채널** — 동일 사유
5. **chunk 분해의 사람 마커** — Q2 에서 LLM 자동 단일 결정. 사람 마커 path 안 만듦
6. **분해 결과 review 게이트** — Q3 에서 100% 자율 결정. review UI/명령 안 만듦
7. **STUCK chunk timeout** — Q5 에서 무한 대기 결정. timeout 메커니즘 안 만듦
8. **master-spec 의 도메인별 자동 chunk 추천 알고리즘** — LLM 일반 분해만, 도메인 학습 X
9. **dispatch 카운터 / 이월 카운터 의 GUI 대시보드** — manifest.md 텍스트로만
10. **다국어 onboarding** — 한국어 디폴트 / 영어 인터뷰 / 등 다국어 지원
11. **GitHub 원격 자동 등록** — 기존처럼 명시 명령 (gh repo create) 으로만
12. **autoCompactEnabled 외 추가 settings 자동화** — 현 상태 유지
13. **이전 v1 의 RESEARCH/IDEATION 산출물 호환성** — 신규 모델 = 새 schema, v1 산출물 import 안 함

---

## 7. 수용 기준 (Acceptance Criteria)

v2 PRD 가 충족됐다는 객관적 증거. NFR-6 의 검증 수용 기준의 정량 표현.

### AC-1. factory template patch 완료

- `template/CLAUDE.md` 에 6원칙 / 대표님-직원 메타포 / INTAKE phase / Telegram 알림 / onboarding 가이드 모두 박힘
- `template/.claude/skills/` 에 onboarding / phase-intake / chunk-detail 신규 스킬 존재
- `template/.claude/skills/` 의 ralph-tick / gate-verify / gap-analysis / project-stop-check / review-council / phase-implement / phase-spec 갱신
- `template/.claude/skills/phase-research`, `ideation-council` 폐기 / 통합
- `template/.claude/agents/{pm,dev,qa,designer,marketer}/` 페르소나 15개 모두 직원 톤 + 대표님 호칭 + (dev) 플래너 책임 제거
- `template/.claude/state/ralph-status.md` phase 정의 표에서 FIXING_* 4개 / IMPLEMENT_PENDING_FREEZE / RESEARCH / IDEATION 제거, INTAKE / CHUNK_DETAIL 추가
- `template/.claude/state/intake/` 디렉터리 + master-spec.md placeholder
- `template/.claude/hooks/notify.sh` + `template/.claude/config/notify.md` (Telegram chat_id placeholder)
- `template/.claude/config/verify-checklist.md` 에 runtime evidence 항목

### AC-2. 슬래시 커맨드 정리

- `template/.claude/commands/` 에서 `ralph-research-done.md`, `ralph-ideation-done.md`, `ralph-spec-done.md` 폐기 또는 의미 변경
- `ralph-run.md` 가 onboarding 자동 진입 흐름 반영

### AC-3. 메타 갱신

- 루트 `CLAUDE.md` 의 7원칙 표 → 6원칙 / 루프 구조 도표 / 동기 섹션 갱신
- `README.md` 빠른 시작 단순화 (도메인 채우기 단계 제거, eject → claude → 알아서 인사 흐름)

### AC-4. end-to-end 검증 1회 통과

- 신규 하네스 (예: `test-v2`) 를 `bash scripts/new-harness.sh test-v2` 로 eject
- `cd ~/jinsup_ralph/test-v2 && claude` 진입 시 ralph 가 onboarding 인사 발화
- 대표님이 ~8 인터뷰 답변 → master-spec 초안 합성 + 동결 → INTAKE 자동 전이
- chunk 분해 manifest 생성 → cycle 1 자동 시작 → chunk 1 의 IMPLEMENT 까지 자율 진행 (코드 1+ 라인 작성)
- CYCLE_DONE 시 Telegram 알림 1회 도달 (chat_id 설정된 경우)
- 이 흐름이 깨짐 없이 완주

### AC-5. 함정 강제 장치 동작 검증

- AC-4 의 cycle 1 동안 gate-verify 가 runtime evidence 항목을 체크 (없으면 FAIL)
- council 단계에서 페르소나 dispatch 가 최소 1회 (cycle 1 → "STOP 직전 cycle = 무조건 dispatch" 룰 적용 시 cycle 1 도 dispatch)
- master-spec chunk 가 council 입력에 명시 박혀 있음 (텍스트 grep 으로 검증 가능)

---

## 8. 제약 / 가정

### 8.1 가정

- ralph-loop 플러그인이 사용자 환경에 활성화되어 있음 (`~/.claude/plugins/cache/claude-plugins-official/ralph-loop/` 존재)
- Telegram MCP 가 connected 상태 (chat_id 발급 가능)
- 사용자가 `~/jinsup_ralph/` 를 destination 으로 사용 (RALPH_HOME 변경 옵션 유지)
- `${CLAUDE_PROJECT_DIR}` 환경변수가 ralph 세션에서 정상 작동

### 8.2 제약

- ralph-loop 플러그인의 Stop hook 메커니즘 자체는 변경 X (외부 의존)
- ~/.claude/settings.json 의 user-global autoCompactEnabled 값 무시 (project-local 강제)
- chunk 1개의 1 cycle 안에 코드 작성까지 완료 = 시간/비용 비현실적이면 검증 부분 통과로 인정

---

## 9. 위험 (preliminary)

상세 위험은 designing-direction 단계에서 다룸. 현재 식별된 큰 위험:

- **R-1**: LLM 자동 chunk 분해가 master-spec 의도와 어긋남 → review 게이트 없으니 6 cycle 까지 가서야 발견. 완화: AC-4 검증으로 cycle 1 에서 catch
- **R-2**: Telegram MCP 끊김 / chat_id 미설정 → 알림 발사 실패. 완화: notify.sh 에 fallback 로깅 (.claude/state/notifications.log)
- **R-3**: 모든 chunk 가 STUCK 으로 빠짐 → 진척 0. 완화: max-iterations 300 cap + manifest 의 BLOCKED 비율 점검
- **R-4**: 대표님 인터뷰 응답이 부족하거나 모호 → master-spec 빈약 → drift 위험 (R-1 과 연관). 완화: onboarding 스킬이 추가 질문 1~2 round 던지도록 (단 무한 X)
- **R-5**: dispatch 최소 cap 강제가 자율성과 충돌 → cycle 시간 ↑. 완화: STOP 직전 cycle 만 무조건 dispatch, 그 외는 2 cycle 마다 1회로 균형

---

## 10. 다음 단계

이 PRD 는 planning-level. 다음:

- `designing-direction` (= `/design`) — `<slug>-tech-design.md` 작성. 아키텍처 / impacted components / 데이터 모델 (state/manifest schema, chunk schema) / 외부 인터페이스 (Telegram MCP / hooks) / key decisions (LLM chunk 분해 prompt / dispatch cap 카운터 메커니즘) / 위험 / 테스팅 전략
- `writing-plans` (= `/write-plan`) — `<slug>-implementation-plan.md` 작성. TDD task 단위 분해

---

## 변경이력

<!-- change-history skill auto-appends entries here, oldest first -->

### [2026-05-10 14:10] [요구사항-수정]

- **id**: CH-20260510-001
- **이유**: 신규 피처 brainstorming 결과 (Socratic 모드, Q1~Q6 6개 결정 포함)
- **무엇이**: ralph-v2-requirements.md 전체 — §1 배경/동기, §2 핵심 결정 (Q1~Q6), §3 사용자 시나리오, §4 FR-1 ~ FR-11, §5 NFR-1 ~ NFR-6, §6 범위 밖 13개, §7 AC-1 ~ AC-5, §8 제약/가정, §9 위험 R-1 ~ R-5, §10 다음 단계
- **영향범위**: 없음 (최초 생성)
