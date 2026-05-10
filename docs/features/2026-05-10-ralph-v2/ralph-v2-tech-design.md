# 개발방향: ralph-v2

> **For agentic workers:** 본 문서는 기술 사양 (architecture / components / data / interfaces / decisions / risks / test strategy). 상위 PRD = `ralph-v2-requirements.md`, 하위 plan = `ralph-v2-implementation-plan.md` (writing-plans 가 작성). 단계별 task 는 본 문서 X — implementation-plan 영역.
>
> **상위 PRD**: `ralph-v2-requirements.md` (CH-20260510-001)

---

## 1. 아키텍처 개요

### 1.1 한 줄 요약

ralph-v2 는 v1 의 self-referential 함정을 **외부 master-spec source-of-truth** + **양 끝(시작/마지막) 1회 사람 게이트** + **LLM tick 직접 Telegram 알림** 으로 해결한다. 인프라는 기존 ralph-loop 플러그인의 Stop hook self-loop 모델 위에 그대로 얹힌다.

### 1.2 데이터 흐름 (Mermaid 대용 ASCII)

```
[대표님 입력]                                    [LLM 처리]                          [State 파일]

대표님 prose      ──onboarding skill──>  ralph LLM 인터뷰      ──Write──>  master-spec.md
"확정" 발화       ──ralph-tick detect─>  freeze flag 검사     ──Write──>  master-spec.frozen

                  ──phase-intake──>      LLM chunk 분해       ──Write──>  intake/chunks/<i>.md
                                                              ──Write──>  intake/manifest.md

                  ──CHUNK_DETAIL──>      페르소나 dispatch    ──Read───   chunks/<i>.md
                                         ⏎ council            ──Write──>  cycles/<N>/spec.md

                  ──IMPLEMENT──>         코드 생성            ──Write──>  app/, web/ 등
                                                              ──Append─>  ralph-history.md

                  ──QA → COUNCIL → GAP → CHECKLIST──>
                  각 phase FAIL → IMPLEMENT 직회귀

                  ──CYCLE_DONE──>        notify-sender skill  ──MCP────>  Telegram (reply)
                                                              ──Write──>  cycles/<N>/runtime-evidence.md

                  ──Telegram reply─────  ralph-tick 다음 tick ──MCP────>  search_threads
                  (대표님 응답)          → manifest update    ──Write──>  manifest.md (BLOCKED 해제)

                  ──PROJECT_DONE──>      Telegram 완료 보고   ──MCP────>  Telegram
```

### 1.3 핵심 패턴

| 패턴 | 위치 | 역할 |
|------|------|------|
| Stop-hook self-loop | ralph-loop 플러그인 (외부) | 매 tick 종료 시 동일 prompt 재투입 |
| Phase machine | `ralph-tick/SKILL.md` | NOT_STARTED → INTAKE → cycle phases → PROJECT_DONE |
| LLM-driven 결정 | `onboarding/`, `phase-intake/`, `chunk-detail/`, `review-council/` 스킬 | 자율 결정 영역 |
| 결정론 helper | shell scripts in `.claude/hooks/` + `.claude/scripts/` | 카운터 / runtime evidence / history append |
| External notify | LLM tick 안에서 MCP 직호출 (notify-sender 스킬) | Telegram 메시지 발사 + 폴링 |
| State persistence | `.claude/state/intake/`, `cycles/<N>/`, `ralph-status.md`, `ralph-history.md` | tick 간 메모리 |

### 1.4 v1 → v2 변화 요약

| 영역 | v1 | v2 |
|------|----|----|
| spec source | ralph 자체 RESEARCH/IDEATION/SPEC | 대표님 master-spec.md (외부) |
| 사람 게이트 | SPEC 동결 N회 (auto-freeze 없으면 매 cycle) | onboarding+freeze 1회 + PROJECT_DONE 1회 |
| RESEARCH/IDEATION | 별도 phase, 발산형 | CHUNK_DETAIL 단일 통합 |
| FIXING_QA/COUNCIL/GAP/CHECK | 4개 별도 phase | 모두 IMPLEMENT 직회귀 |
| IMPLEMENT_PENDING_FREEZE | 사람 인가 게이트 | 제거 (master-spec 이 곧 frozen) |
| 7원칙 | 7개 | 6개 (플래너 #3 제거) |
| 외부 알림 | 없음 | Telegram MCP 3 시점 |

---

## 2. 영향 받는 컴포넌트/파일

### 2.1 FR → 파일 매핑

| FR | 영향 파일/컴포넌트 |
|----|------------------|
| FR-1 (6원칙) | 루트 `CLAUDE.md`, `template/CLAUDE.md`, `template/README.md`, `README.md`, `template/.claude/agents/dev/*` (플래너 책임 제거), `template/.claude/skills/phase-implement/SKILL.md` (플래너 사전 호출 제거) |
| FR-2 (대표님-직원) | `template/CLAUDE.md` (사용자 동기 섹션), 15 페르소나 (`template/.claude/agents/{pm,dev,qa,designer,marketer}/*.md`), council/QA/GAP/CHECKLIST/notify 산출물 톤 가이드 |
| FR-3 (master-spec 모델) | 신규 `template/.claude/skills/phase-intake/`, 신규 `template/.claude/state/intake/master-spec.md` (placeholder) + `intake/chunks/` + `intake/manifest.md`, 갱신 `template/.claude/skills/{gap-analysis, project-stop-check, review-council}/SKILL.md` |
| FR-4 (DONE 재정의) | `template/.claude/skills/project-stop-check/SKILL.md`, `template/.claude/state/ralph-status.md` (phase 정의 표) |
| FR-5 (함정 강제) | `template/.claude/skills/gate-verify/SKILL.md` (runtime evidence), `template/.claude/state/intake/manifest.md` (이월/dispatch counter), `template/.claude/skills/review-council/SKILL.md` (dispatch cap) |
| FR-6 (FIXING_* 제거) | `template/.claude/skills/ralph-tick/SKILL.md`, `template/.claude/state/ralph-status.md` |
| FR-7 (CHUNK_DETAIL 통합) | 신규 `template/.claude/skills/chunk-detail/SKILL.md`, 폐기 `template/.claude/skills/phase-research/`, `template/.claude/skills/ideation-council/` |
| FR-8 (PENDING_FREEZE 제거) | `template/.claude/skills/ralph-tick/SKILL.md`, `template/.claude/commands/ralph-spec-done.md` (폐기 또는 ralph-respec 으로 의미 변경) |
| FR-9 (Telegram 알림) | 신규 `template/.claude/skills/notify-sender/SKILL.md`, `template/.claude/config/notify.md` (chat_id placeholder + 메시지 schema 가이드) |
| FR-10 (onboarding 진입) | 신규 `template/.claude/skills/onboarding/SKILL.md`, 갱신 `template/.claude/skills/ralph-tick/SKILL.md` (NOT_STARTED phase), 갱신 `template/CLAUDE.md` (도메인 → onboarding 가이드) |
| FR-11 (STUCK 우회) | `template/.claude/skills/ralph-tick/SKILL.md` (BLOCKED 우회 로직), `template/.claude/state/intake/manifest.md` (BLOCKED 상태) |

### 2.2 신규 / 폐기 스킬 정리

| 분류 | 스킬 |
|------|------|
| 신규 | `onboarding/`, `phase-intake/`, `chunk-detail/`, `notify-sender/` (4개) |
| 폐기 | `phase-research/`, `ideation-council/` (2개) |
| 갱신 | `ralph-tick/`, `gate-verify/`, `gap-analysis/`, `project-stop-check/`, `review-council/`, `phase-implement/`, `phase-spec/` (7개) |
| 무변 | `verify-loop-output/`, `phase-qa-review/`, `phase-debug/` (3개) |

총 v2 스킬 = 14개 (v1: 12개 → +4 신규 -2 폐기 = +2)

### 2.3 신규 / 폐기 슬래시 커맨드

| 분류 | 커맨드 |
|------|--------|
| 신규 | `/ralph-respec` (선택 — master-spec 갱신 후 INTAKE 재실행 트리거) |
| 폐기 | `/ralph-research-done`, `/ralph-ideation-done`, `/ralph-spec-done`, `/ralph-cycle-start` (폐기 또는 의미 변경) |
| 갱신 | `/ralph-run` (onboarding 자동 진입), `/ralph-tick`, `/ralph-stop` |
| 무변 | `/ralph-deploy`, `/ralph-done`, `/ralph-verify`, `/ralph-start` |

### 2.4 페르소나 (15개 모두 톤만 갱신)

`template/.claude/agents/{pm,dev,qa,designer,marketer}/*.md` 의 frontmatter `description` 에 "대표님 호칭, 보고체 톤" 명시. dev/* 3개는 플래너 책임 명시 제거.

---

## 3. 데이터 모델/스키마 변경

### 3.1 master-spec.md (대표님 작성)

**위치**: `.claude/state/intake/master-spec.md`

**Schema** — prose 자유 + 가벼운 메타 헤더

```markdown
---
project: <project-name>
version: 1
frozen: false                    # "확정" 발화 시 ralph 가 true 로 전환
frozen_at: null                  # ISO 8601 timestamp
---

# 비전

<대표님 자유 prose>

# 대상 사용자 / 시나리오

<prose>

# 핵심 산출물

<prose>

# 성공 정의

<prose>

# 금지 / 범위 밖

<prose>

# 외부 의존 / 제약

<prose>
```

→ 섹션은 onboarding 인터뷰 결과로 ralph 가 합성. 대표님이 직접 작성해도 됨.

### 3.2 chunks/<i>.md (LLM 분해 산출물)

**위치**: `.claude/state/intake/chunks/01.md`, `02.md`, …

**Schema**

```markdown
---
chunk_id: 01
title: <한 줄 요약>
order: 1                         # manifest 의 의존성 순서대로
depends_on: []                   # 다른 chunk_id 리스트 (비어있으면 독립)
estimated_cycles: 1              # 보통 1 (지나치게 크면 분해 재실행 권고)
---

# <title>

## 출처 (master-spec 발췌)

<master-spec 의 어느 부분에서 도출됐는지 1-3 문단 인용>

## 이번 cycle 의 목표

<prose>

## acceptance criteria

- AC-CHUNK-<id>-1: <측정 가능>
- AC-CHUNK-<id>-2: ...
- ...

## 비고 (LLM 자동 분해 결과 — drift 의심 시 대표님이 직접 수정 가능)

<prose>
```

### 3.3 manifest.md (chunk 메타)

**위치**: `.claude/state/intake/manifest.md`

**Schema** — markdown + YAML frontmatter

```markdown
---
total_chunks: 8
generated_at: 2026-05-10T14:00:00Z
generator: llm-auto                # 또는 manual / mixed
---

# Chunk Manifest

## 진행 표

| chunk_id | title | status | cycle | dispatch_count | deferral_count |
|----------|-------|--------|-------|----------------|----------------|
| 01 | docker-compose 풀스택 | DONE | 1 | 1 | 0 |
| 02 | 정부24 어댑터 | IN_PROGRESS | 2 | 1 | 0 |
| 03 | LLM 본문 추출 | PENDING | - | 0 | 0 |
| 04 | 개인화 추천 | BLOCKED | - | 0 | 1 |
| 05 | UX 라벨 피드백 | PENDING | - | 0 | 0 |
| ... |

## 상태 정의

- `PENDING`: 아직 cycle 진입 안 함
- `IN_PROGRESS`: 현 cycle 진행 중
- `DONE`: CHECKLIST PASS + project-stop-check 의 chunk 소진 인정
- `BLOCKED`: STUCK 으로 보류 (대표님 응답 대기 또는 의존 chunk 미해결)

## counters

- `dispatch_count`: 이 chunk 가 council 단계에서 진짜 페르소나 dispatch 받은 횟수 (FR-5 cap 검증용)
- `deferral_count`: 이 chunk 의 acceptance 일부가 다른 chunk 로 이월된 횟수 (≥3 → BLOCKED + Telegram)

## BLOCKED 사유 로그

### chunk 04 — 개인화 추천 (2026-05-12T09:00:00Z)

- **사유**: master-spec 의 "관심 카테고리 가중치" 가 모호. 자동 분해 결과 acceptance 가 측정 불가
- **재개 조건**: 대표님 응답 (Telegram reply) 또는 master-spec 갱신 후 /ralph-respec
```

### 3.4 cycles/<N>/runtime-evidence.md

**위치**: `.claude/state/cycles/<N>/runtime-evidence.md`

**Schema** — 필수 항목 매 cycle. 미작성 시 CHECKLIST FAIL.

```markdown
# Runtime Evidence — Cycle N

생성: 2026-05-12T15:00:00Z
chunk: 02 — 정부24 어댑터

## 자동 검증 (테스트만으로는 충족 X)

- [ ] docker-compose up -d 1회 성공
- [ ] /health 200 응답
- [ ] /api/feed 응답에 chunk acceptance 표적 데이터 포함
- [ ] (UI 있으면) 헤드리스 브라우저로 핵심 인터랙션 1회 시뮬레이션

## 캡처 (curl 출력 / 스샷 / 로그)

```
$ curl http://localhost:8000/api/feed
{"items":[{"id":"...","title":"...","cta_url":"https://www.gov.kr/..."}]}
```

## 위 결과로부터 chunk acceptance 충족 판정

- AC-CHUNK-02-1 (어댑터 동작): ✅ /api/feed 에 정부24 출처 1+ 카드
- AC-CHUNK-02-2 (URL 진위): ⚠ partial — generic landing 비율 점검 미완 → 다음 cycle 보강 (deferral_count++)
```

### 3.5 ralph-status.md (phase 정의 갱신)

```markdown
# ralph status

cycle: <N>
phase: <PHASE>
last_intake: <timestamp>           # INTAKE 마지막 실행
last_dispatch: <cycle:phase>       # FR-5 cap 검증용
last_telegram: <timestamp>         # 마지막 Telegram 발사
fail_streak: 0

---

## phase 정의 (v2)

NOT_STARTED            # master-spec 미동결 → onboarding 모드
   → INTAKE            # master-spec 동결 후 1회만 — chunk 분해
   → CHUNK_DETAIL      # cycle 시작. chunk 의 구현 방안 + 디테일
   → SPEC              # chunk 상세화
   → IMPLEMENT         # 코드 생성
   → QA_REVIEW         # FAIL → IMPLEMENT 직회귀
   → REVIEW_COUNCIL    # FAIL → IMPLEMENT 직회귀, dispatch cap 적용
   → GAP_ANALYSIS      # FAIL → IMPLEMENT 직회귀
   → CHECKLIST         # FAIL → IMPLEMENT 직회귀, runtime evidence 필수
   → CYCLE_DONE        # Telegram 진척 알림
   → project-stop-check
        ├ chunks 소진 → PROJECT_DONE → Telegram 완료
        └ 미달 → 다음 chunk → CHUNK_DETAIL
   → STUCK_<phase>     # fail_streak ≥5 또는 deferral_count ≥3 → BLOCKED + Telegram + 우회

## 폐기 phase (v1)
RESEARCH, IDEATION, IMPLEMENT_PENDING_FREEZE,
FIXING_QA, FIXING_COUNCIL, FIXING_GAP, FIXING_CHECK
```

### 3.6 notify.md (config)

**위치**: `.claude/config/notify.md`

```markdown
# Notify Config

telegram_chat_id: <대표님이 채워넣음 / onboarding 첫 질문에서 받음>
default_channel: telegram

## 메시지 schema (대표님 톤)

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

---

## 4. 외부 인터페이스

### 4.1 Telegram MCP — 발사 (push)

**도구**: `mcp__plugin_telegram_telegram__reply` (가능 시) 또는 동등 MCP tool

**호출 위치**: `notify-sender/SKILL.md` 가 ralph-tick 의 phase 분기에서 invoke

**파라미터**:

- `chat_id`: notify.md 의 `telegram_chat_id`
- `message`: 시점별 schema 적용한 텍스트

**fallback**: MCP 실패 시 `.claude/state/notifications.log` 에 append 후 ralph-history 에 `[notify] FAIL <reason>` 기록. 다음 tick 에서 재시도 X (cycle 내 1회만 attempt — 무한 루프 방지)

### 4.2 Telegram MCP — 폴링 (대표님 reply)

**도구**: `mcp__plugin_telegram_telegram__search_threads` + `get_thread`

**호출 위치**: ralph-tick 의 매 iteration 시작 시 (phase 무관) `notify-sender` 가 thread 폴링 → 새 메시지가 있으면 `.claude/state/inbox/<timestamp>.md` 에 저장 + ralph-history 에 `[telegram-reply] <summary>` 기록

**처리**: 다음 tick 의 phase dispatch 가 inbox 를 봐서 BLOCKED 상태인 chunk 와 매칭 시 manifest 갱신

**SLA 없음**: 응답이 며칠 늦어도 BLOCKED chunk 는 무한 대기 (max-iterations 300 cap 만 작동)

### 4.3 ralph-loop 플러그인 (외부)

**의존**: `~/.claude/plugins/cache/claude-plugins-official/ralph-loop/<version>/scripts/setup-ralph-loop.sh`

**진입**: `/ralph-run` 슬래시 커맨드가 setup-ralph-loop.sh 직접 호출 (변경 없음)

**Stop hook**: ralph-loop 가 등록한 hook 이 세션 종료 가로채서 동일 prompt 재투입 (변경 없음)

### 4.4 Hooks

```
.claude/hooks/append-history.sh    # PostToolUse — 변경 없음
.claude/hooks/run-verify.sh        # Stop — gate-verify 호출, runtime evidence 점검 추가
```

신규 hook 추가 X (notify 는 LLM 안에서 MCP 직호출, hook 영역 X).

---

## 5. 핵심 결정 + 대안 비교

### 5.1 D-1 — Telegram 알림 구현: MCP 직호출 ✅

**대안**:

- (a) MCP 직호출 (LLM tick 안) — 채택
- (b) Bot API direct via curl in shell hook
- (c) Queue + tick 소비 하이브리드

**선택 이유 (사용자 결정)**:

- bot token 보관 불필요 (MCP 가 인증 처리)
- hook 안에서 동작 안 해도 OK — ralph-tick 자체가 LLM 세션이라 MCP 호출 가능
- 메시지 합성 = LLM 영역 (대표님 톤 보고서) 이라 LLM 안에서 처리하는 게 자연

**트레이드오프**: 대표님 reply 도 LLM tick 안에서만 처리. ralph 가 자고 있으면 reply 누적 → 다음 ralph-loop 시작 시 일괄 흡수 (NFR-3 SLA 없음과 일관)

### 5.2 D-2 — chunk 분해 알고리즘: LLM 자동 ✅

**대안**:

- (a) 사람이 master-spec 안에 chunk 마커 표시
- (b) ralph 가 LLM 자동 분해 — 채택
- (c) 둘 다 (사람 표시 우선)

**선택 이유 (사용자 결정 Q2)**: 대표님 작성 부담 ↓, prose 자유. drift 위험은 cycle 1 의 e2e 검증 (AC-4) 으로 catch.

**트레이드오프**: 분해 결과 review 게이트 없음 (Q3 와 일관). cycle 1 까지 가서야 잘못된 분해 발견. 완화 = LLM 분해 prompt 에 "master-spec 인용 + 기준 명시" 강제.

**chunk 분해 prompt skeleton** (phase-intake/SKILL.md 안에 박힘):

```
당신은 대표님의 master-spec 을 1 cycle 분량의 chunk 로 분해합니다.

원칙:
1. 모든 chunk 는 master-spec 의 명시 항목에서 도출. 새 가치 추가 금지.
2. 1 chunk = 1 cycle. acceptance 5~10개. 너무 크면 sub-chunk 로.
3. 의존성 있는 chunk 는 depends_on 에 명시.
4. 각 chunk 의 출처 인용 (master-spec 의 어느 문단) 필수.

출력 형식: chunks/<i>.md (Schema 참조) + manifest.md (Schema 참조)
```

### 5.3 D-3 — STUCK 시 동작: 보류 후 우회 ✅

**대안**:

- (a) 무한 대기 (응답까지 noop)
- (b) 보류 후 다음 chunk 진행 — 채택
- (c) timeout 후 best-guess

**선택 이유 (사용자 결정 Q5)**: 100% 자율 철학 일관. STUCK chunk 만 멈춤, 다른 chunk 진행.

**구현**:

- `manifest.md` 의 chunk status 를 `BLOCKED` 로 마크
- ralph-tick 의 phase dispatch 가 다음 PENDING chunk 로 진행
- BLOCKED chunk 는 PROJECT_DONE 시점 보고에 포함

### 5.4 D-4 — 7원칙 처리: 6원칙 축소 ✅

**대안**:

- (a) 6원칙 축소 — 채택
- (b) 신규 원칙 #3 = "외부 master-spec source-of-truth"
- (c) 다른 원칙 승격

**선택 이유 (사용자 결정 Q1)**: 단순. 플래너 행 그냥 삭제.

**영향**: 7원칙 매핑 표가 6행으로. 헌법 자리에 master-spec 모델 박지 않으니 다른 곳 (CLAUDE.md 운영 가정 / phase-intake 스킬) 에 명시.

### 5.5 D-5 — dispatch cap 강제 메커니즘

**대안**:

- (a) `manifest.md` 의 `dispatch_count` 카운터 사용 — 채택
- (b) 별도 `cycles/dispatch.log`
- (c) 각 cycle md 에 dispatch 발화 기록

**선택**: a. manifest 단일 source. council 단계 진입 시 dispatch_count 보고 결정:

- 현 cycle = STOP 직전 cycle? → 무조건 dispatch (FR-5)
- 현 cycle - last_dispatch_cycle ≥ 2? → 무조건 dispatch
- 그 외 → 메인 self-synth OK

"진짜 dispatch" 의 정의 = 페르소나 agent 를 Agent tool 로 실 호출 (메인 LLM 의 self-synth 가 아님).

### 5.6 D-6 — master-spec 동결 트리거

**대안**:

- (a) 대표님이 "확정" 키워드 발화 시 ralph 가 frontmatter `frozen: true` 로 갱신
- (b) `/ralph-spec-confirm` 슬래시 커맨드
- (c) 둘 다 — 채택

**선택**: c. 키워드는 자연 (대화 중 발화), 슬래시는 명시 (어색하면 OK). 둘 다 지원으로 대표님 부담 ↓.

**구현**: `onboarding/SKILL.md` 가 대화 중 "확정" / "OK" / "진행해" 같은 confirm 신호 감지 OR 사용자가 명시 슬래시 호출 시 동결.

### 5.7 D-7 — onboarding 인터뷰 깊이

**대안**:

- (a) 5 질문 (짧음)
- (b) 8 질문 — 채택
- (c) 10+ 질문 (포괄)

**선택**: b. PRD §3.2 사용자 발화 ~8 답변과 일관.

**8 질문 catalog** (구체화):

1. 이 프로젝트 한 줄 비전?
2. 누가 사용? (1-2 문장 페르소나)
3. 핵심 산출물 1-3개?
4. "성공" 의 정의 (정량 + 정성)?
5. 절대 만들지 말 것 (범위 밖)?
6. 외부 의존 (API / 데이터 소스 / 사용자 입력)?
7. 규모 / 일정 / 비용 cap (cycles ≤ N)?
8. Telegram chat_id (이걸로 진척 보고드림)

**부족 응답 처리**: 답변이 모호하면 1-2 round 추가 질문 (무한 X). 끝까지 모호하면 master-spec 에 "확정 필요" 표기 + onboarding 종료 시 대표님께 알림.

### 5.8 D-8 — runtime evidence 자동화 범위

**대안**:

- (a) docker compose + curl 표준 자동화 명령 강제 (도메인 무관)
- (b) 도메인별 가이드만, 명령은 도메인 스크립트 (`.claude/scripts/runtime-evidence.sh` 도메인이 채움) — 채택
- (c) 자동화 X, 사람이 매번 캡처

**선택**: b. 도메인 다양성 흡수. template 은 `runtime-evidence.sh` placeholder 만 제공, 도메인 SPEC 단계에서 채움.

**Fallback**: `runtime-evidence.sh` 실행 실패 시 ralph 가 직접 docker compose + curl 시도 (로컬 환경 가정).

---

## 6. 위험/사이드이펙트 (preliminary)

PRD §9 의 R-1~R-5 + tech-design 단계 추가 발견.

### R-1. LLM chunk 분해 의도 어긋남 (PRD)

- **카테고리**: side-effect
- **영향**: cycle 1~6 까지 그대로 갈 수 있음
- **완화**: AC-4 e2e 검증으로 cycle 1 완주 시점 catch + chunk 분해 prompt 에 "master-spec 인용 강제"
- **잔여**: 사람 review 게이트 없으니 cycle 1 미만 catch 불가

### R-2. Telegram MCP 끊김 (PRD)

- **카테고리**: side-effect
- **영향**: 알림 발사 실패 → 대표님 진척 모름
- **완화**: notify-sender 가 MCP 실패 시 `.claude/state/notifications.log` 로 fallback + ralph-history 에 `[notify] FAIL` 기록
- **잔여**: log 만 보면 대표님이 모름. 실 운영에선 MCP 상태 점검 hook 필요할 수 있음

### R-3. 모든 chunk BLOCKED → 진척 0 (PRD)

- **카테고리**: side-effect
- **영향**: max-iterations 300 까지 noop
- **완화**: `manifest.md` 의 BLOCKED 비율이 ≥50% 도달 시 자동 PROJECT_DONE 강제 + Telegram 알림 (대표님 개입 요청)

### R-4. 인터뷰 응답 모호 → master-spec 빈약 (PRD)

- **카테고리**: side-effect
- **영향**: chunk 분해 결과도 빈약 (R-1 과 연관)
- **완화**: onboarding 의 추가 질문 1-2 round + master-spec 에 "확정 필요" 표기 + 대표님 알림

### R-5. dispatch cap 자율성 충돌 (PRD)

- **카테고리**: perf (cycle 시간 ↑)
- **영향**: 매 2 cycle 1회 dispatch 강제 시 council 단계 ~30s 추가
- **완화**: STOP 직전 cycle 만 무조건 dispatch + 그 외는 2 cycle 마다 1회 cap (이미 PRD 에 박힘)

### R-6. Telegram MCP chat_id 발급 절차 미정 (신규)

- **카테고리**: breaking — 첫 진입 시 chat_id 가 없으면 알림 0
- **영향**: onboarding 끝나고 cycle 1 진행해도 알림 발사 안 됨
- **완화**: onboarding 인터뷰 8번째 질문 = chat_id. 응답 없으면 master-spec 에 "telegram_chat_id MISSING" 기록 + 매 CYCLE_DONE 시 콘솔 fallback (.claude/state/notifications.log) 사용
- **사용자 책임**: Telegram MCP 의 /telegram:access skill 로 chat_id 발급 (별도 스킬, 본 PRD 범위 밖)

### R-7. master-spec 너무 길어 LLM context 한계 (신규)

- **카테고리**: side-effect
- **영향**: chunk 분해 시 master-spec 전체 입력 → 1M token cap 한계
- **완화**: master-spec.md 길이 cap 권고 (예: ≤ 50KB / ~10000 tokens). onboarding 가이드에 명시. 초과 시 phase-intake 가 1차 요약 후 분해

### R-8. INTAKE chunk 분해 idempotency (신규)

- **카테고리**: race
- **영향**: INTAKE 두 번 호출 시 분해 결과가 다를 수 있음 → manifest 가 갈리면서 진행 중 chunk 의 status 가 사라짐
- **완화**: INTAKE skill 이 `intake/manifest.md` 존재 시 noop (idempotency). 재분해 원하면 명시 `/ralph-respec` 슬래시 커맨드 호출

### R-9. dispatch_count vs deferral_count counter 동기화 실패 (신규)

- **카테고리**: race
- **영향**: review-council 이 dispatch 후 manifest 갱신 실패 → 다음 cycle 에서 cap 룰 잘못 판정
- **완화**: counter 갱신을 LLM tick 안에서 단일 Edit 으로. 여러 단계 분리 X. + 매 phase 종료 시 grep 으로 검증

### R-10. v1 ↔ v2 슬래시 커맨드 전환 충돌 (신규)

- **카테고리**: breaking
- **영향**: 기존 하네스 (show-money, GodMode, PlanB) 가 폐기된 `/ralph-research-done` 등 호출 시 깨짐
- **완화**: 폐기 커맨드는 즉시 삭제 X — `[deprecated]` 스텁으로 1 minor version 유지 (호출 시 안내 메시지). 다음 메이저에서 삭제

---

## 7. 테스트 전략

### 7.1 정적 검증 (AC-5 grep)

template patch 후 `bash scripts/verify-v2-template.sh` (신규) 가 다음 전부 PASS:

- `template/CLAUDE.md` 에 "6원칙" 키워드 존재 + "7원칙" 키워드 없음
- `template/.claude/skills/` 에 `onboarding/`, `phase-intake/`, `chunk-detail/`, `notify-sender/` 존재
- `template/.claude/skills/` 에 `phase-research/`, `ideation-council/` 부재
- `template/.claude/state/intake/master-spec.md` placeholder 존재
- `template/.claude/state/ralph-status.md` 의 phase 정의 표에 INTAKE/CHUNK_DETAIL 존재 + FIXING_*/IMPLEMENT_PENDING_FREEZE/RESEARCH/IDEATION 부재
- 15 페르소나 모두 frontmatter 에 "대표님" 키워드 1+ 회

### 7.2 e2e 검증 (AC-4)

```bash
bash scripts/new-harness.sh test-v2
cd ~/jinsup_ralph/test-v2
claude     # 새 세션 — onboarding 발화 자동
```

수동 검증 항목:

1. ralph 가 즉시 "대표님 안녕하십니까" 발화
2. 대표님이 8 질문 답변 (chat_id 포함)
3. master-spec 동결 ("확정" 발화 시)
4. INTAKE 자동 전이 → manifest.md 생성
5. cycle 1 자동 시작 → CHUNK_DETAIL → SPEC → IMPLEMENT 까지 자율
6. CHECKLIST 시점 runtime-evidence.md 강제
7. CYCLE_DONE 도달 시 Telegram 알림 1회 (chat_id 설정된 경우)

이 흐름 깨짐 없으면 v2 PROJECT_DONE.

### 7.3 단위 테스트 (선택, low priority)

각 신규 스킬에 대해 LLM 호출 자체는 unit test 어려움. 대신:

- **prompt smoke**: 스킬의 핵심 프롬프트 텍스트가 grep 으로 검증 (예: chunk-detail/SKILL.md 에 "새 가치 추가 금지" 키워드 존재)
- **counter math**: dispatch_count 증가 로직 (manifest Edit) 의 idempotency 를 Python helper 로 단위 검증 (있으면 가산점)

### 7.4 통합 테스트 (생략)

template 자체는 LLM 의존이라 통합 테스트 어려움. AC-4 e2e 가 통합 테스트 역할.

### 7.5 회귀 방지 — show-money 마이그레이션 가이드 (out-of-scope)

PRD §6 에서 out-of-scope. 본 PRD 의 범위 밖 — 별도 결정 시 별도 작업.

---

## 변경이력

<!-- change-history skill auto-appends entries here, oldest first -->

### [2026-05-10 14:32] [개발방향-수정]

- **id**: CH-20260510-002
- **이유**: 신규 기술 설계 — ralph-v2-requirements.md 의 FR-1 ~ FR-11, NFR-1 ~ NFR-6, AC-1 ~ AC-5 을 7섹션 기술 사양으로 정리. Telegram MCP 직호출 결정 (D-1) 포함.
- **무엇이**: ralph-v2-tech-design.md 전체 — §1 아키텍처 (data flow + 패턴 + v1↔v2 변화), §2 영향 컴포넌트 (FR 매핑 + 스킬 14개 + 명령 8개 + 페르소나 15개), §3 데이터 모델 (master-spec/chunks/manifest/runtime-evidence/ralph-status/notify schema), §4 외부 IF (Telegram MCP push+poll, ralph-loop 의존), §5 핵심 결정 D-1 ~ D-8 + 대안, §6 위험 R-1 ~ R-10 (PRD R-1~5 + tech 추가 R-6~10), §7 테스트 전략 (정적 grep + e2e 수동)
- **영향범위**: 없음 (최초 생성). verify-spec 4축 보고서 PASS — 22/22 mapped, 0 conflicts. 산술 정정 1건 inline 적용 (스킬 카운트 13→14, v1 11→12).
- **연관 항목**: CH-20260510-001 (PRD)
