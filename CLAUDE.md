# CLAUDE.md

ralph loop 전용 하네스를 세팅하기 위한 프로젝트 입니다.
Claude Code 로 이 프로젝트를 실행해서 랄프로 진행되는 프로젝트를 위한 하네스를 세팅할 예정입니다.

- 이 프로젝트(`js-ralph`)는 **하네스 공장**이다. 직접 ralph 실행 환경을 운영하지 않고, 템플릿 + 스캐폴딩 스크립트만 보유한다.
- 모든 하네스의 **공통 템플릿**은 루트 `template/` 에 둔다.
- 새 하네스는 `template/` 을 복제하여 **외부 디렉터리** `${RALPH_HOME:-$HOME/jinsup_ralph}/<project>/` 로 eject 한다. 그 자리에서 자체 git 저장소가 된다 (`git init -b main` 자동, 초기 커밋 자동).
- 따라서 이 프로젝트 안에는 실제 하네스 인스턴스가 살지 않는다. `harness-ralph/` 폴더는 **사용하지 않는다** (의도적으로 비어 있음).
- 루트 `.claude/commands/` 에는 하네스 생성·관리용 메타 커맨드만 둔다 (개별 하네스 동작 커맨드는 각 하네스의 `.claude/commands/`).
- **template/CLAUDE.md 는 자가완결**이어야 한다 (eject 후 부모 참조 불가). 루트의 6원칙/게이트 구조가 바뀌면 template/CLAUDE.md 도 같이 갱신.

---

## 최종 목적 (이 프로젝트가 만들고자 하는 것)

**"6원칙을 Claude Code 네이티브 인프라(`.claude/`)에 1:1 매핑한, 강제력 있는 ralph 하네스 템플릿"** 을 각 도메인별로 만든다.

원칙은 문서로만 존재하면 안 된다. `.claude/agents`, `.claude/skills`, `.claude/hooks`, `.claude/commands` 로 코드/설정에 박혀서 사람·에이전트의 의지와 무관하게 강제되어야 한다.

### 운영 가정 — ralph-loop 자율 구동

이 하네스는 **`ralph-loop` 플러그인이 돌린다는 가정**으로 설계되어 있다. 즉 사람이 매번 슬래시 커맨드를 치는 manual 모델이 아니라, ralph-loop 가 정해진 entry 를 반복 invoke 하면 agent 가 자율로 한 스텝씩 전진한다.

- **메인 경로**: `ralph-tick` (`.claude/commands/ralph-tick.md` + 동일 이름 스킬). ralph-loop 가 매 iteration 마다 호출. tick 1회 = 현재 phase 1 step + gate-verify + status 갱신 후 exit.
- **수동 override**: `/ralph-tick` (한 번만 1 step), `/ralph-stop` (PROJECT_DONE 으로 굳히기). 사람이 끼고 싶을 때만 사용.
- **사람 강제 인가 지점**: **2회뿐** — ① master-spec 동결 (onboarding 인터뷰 후 "확정" 발화), ② PROJECT_DONE 최종 검토. 매 cycle 사람 게이트 없음.
- 정지: 모든 chunk 수용 완료 시 `project-stop-check` 가 `phase=PROJECT_DONE` 으로 굳히고 ralph-loop 도 cancel 안내. 사용자 명시 정지는 `/ralph-stop` 또는 `ralph-loop:cancel-ralph`.

### 동기 (왜 이 모양인가)

이 하네스의 사용자는 **대표님 (방향 결정자)** 이다. 5역할 페르소나는 **직원**이다.
대표님은 비전과 master-spec 을 제공하고, 직원(페르소나 풀)이 그것을 실행한다.
→ 대표님은 시작(onboarding 인터뷰 ~8 답변 + 동결 1회)과 끝(PROJECT_DONE 검토 1회)에만 참여하고, 중간 모든 과정은 ralph 가 100% 자율 진행한다.

### 기본 기술 스택 (사용자 디폴트, 명시적 다른 지시 없으면 이대로 간다)

| 영역 | 기본 스택 |
|------|-----------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React |
| Mobile App | Android (Kotlin, Android Studio). **iOS / Flutter 는 의도적으로 포기.** |
| Database | Postgres |
| 그 외 (인프라/CI/캐시 등) | 합리적 기본값 알아서 결정 |

새 하네스가 위 4 카테고리 중 하나로 결정되는 순간, 다시 묻지 말고 이 조합으로 시작한다. 다른 스택을 쓰려면 사용자의 명시적 지시가 있어야 한다. 이 디폴트는 `template/CLAUDE.md` 의 같은 섹션에도 박혀 있어 eject 후에도 유지된다.

> **모든 하네스 설정/상태/스크립트는 `.claude/` 안에만 둔다.** 외부 폴더(bootstrap/, memo/, config/ 등)를 따로 두지 않는다 — 중복이고 산만해진다. 각 하네스 루트엔 `CLAUDE.md`, `README.md`, `.claude/` 만 존재한다 (그 외는 하네스가 만드는 실제 산출물 디렉터리).

### 6원칙 ↔ Claude Code 인프라 매핑

| 원칙 | 매핑 위치 | 강제 메커니즘 |
|------|-----------|----------------|
| 1. 자체 검증 | `.claude/skills/verify-*` + `.claude/hooks/run-verify.sh` (Stop hook) + `.claude/config/verify-checklist.md` | 루프 종료 시 훅이 검증 스킬 자동 호출 |
| 2. 프롬프트 라우팅 | `.claude/skills/phase-*/` + `.claude/commands/` | 페이즈별 스킬/슬래시 커맨드 분리, 단일 시스템 프롬프트 금지 |
| 3. Ralph 히스토리 | `.claude/hooks/append-history.sh` (PostToolUse) → `.claude/state/ralph-history.md` | 훅이 자동 append |
| 4. 모델 라우팅 | 각 agent `model:` frontmatter + `.claude/config/model-routing.md` | agent 정의에 모델 박힘 |
| 5. 배포 선세팅 | `.claude/scripts/{deploy,smoke-test}.sh` + `.claude/commands/ralph-deploy.md` | 첫 그린 라이트 통과 전엔 `/ralph-start` 차단 |
| 6. 페르소나 풀 | `.claude/agents/persona-<role>-<variant>.md` (역할당 N개) | 리뷰/검증 단계가 다중 페르소나 agent 병렬 호출 |

### 루트 레이아웃 (이 프로젝트 자체)

```
js-ralph/                                    # 공장 (factory) — 직접 실행 환경 아님
  CLAUDE.md                                  # 이 파일
  template/                                  # 모든 하네스의 원본 (복제 대상)
  scripts/
    new-harness.sh                           # template/ → ~/jinsup_ralph/<name>/ eject + git init
  .claude/
    commands/
      ralph-new.md                           # /ralph-new <name> 메타 커맨드
  harness-ralph/                             # 사용 안 함 (비어 있음, vestigial)
```

### Eject 결과 위치 (실제 하네스가 사는 곳)

```
~/jinsup_ralph/<project>/                    # ← RALPH_HOME 환경변수로 변경 가능
  .git/                                      # 자체 git 저장소
  CLAUDE.md  README.md  .claude/             # 하네스 표준 레이아웃 (아래)
```

### 하네스 표준 레이아웃 (template/ 및 ~/jinsup_ralph/<project>/)

```
<project>/                 # template/ 을 복제하고 eject 한 결과
  CLAUDE.md                # 6원칙 + 게이트 구조 + 도메인 특수 규칙 (자가완결)
  README.md                # 사용법 + 6원칙 구현 매핑 표
  .claude/
    settings.json          # hooks 등록, 권한, env
    agents/                # 원칙 4·6 (+ 각 agent 의 model: 필드로 원칙 4)
      pm/         (≥3 페르소나)
      dev/        (≥3 페르소나)
      qa/         (≥3 페르소나)
      designer/   (≥3 페르소나, 컨텍스트 활성)
      marketer/   (≥3 페르소나, 컨텍스트 활성)
    skills/                # 원칙 1·2
      verify-loop-output/  #   체크리스트 (객관)
      gate-verify/         #   게이트 간 공통 검증
      onboarding/          #   대표님 인터뷰 → master-spec 합성
      phase-intake/        #   master-spec → chunk 분해
      chunk-detail/        #   chunk 구현 방안 디테일 (발산)
      phase-spec/          #   기획/디자인 동결
      phase-implement/
      phase-qa-review/     #   QA 단계
      review-council/      #   전체회의 (수렴)
      gap-analysis/        #   남은 요구사항 추출
      phase-debug/
      notify-sender/       #   Telegram 알림 발사 (3 시점)
      project-stop-check/  #   chunk 소진 여부 채점
      ralph-tick/          #   매 iteration entry (자율 구동 핵심)
    commands/              # 원칙 2·5
      ralph-run, ralph-tick, ralph-stop, ralph-respec,
      ralph-start, ralph-done, ralph-verify, ralph-deploy
    hooks/                 # 원칙 1·3 강제용 스크립트
      append-history.sh    #   원칙 3
      run-verify.sh        #   원칙 1
    scripts/               # 원칙 5 (deploy.sh, smoke-test.sh, runtime-evidence.sh)
    state/                 # 원칙 3 작업기억 + 게이트 상태
      ralph-history.md     #   append-only 로그 (모든 hook/transition)
      ralph-status.md      #   {cycle, phase, last_intake, last_dispatch, last_telegram}
      notifications.log    #   Telegram fallback 로그
      intake/              #   master-spec 모델
        master-spec.md     #     대표님 작성 prose (frozen: false → true)
        manifest.md        #     chunk 진행 표 (PENDING/IN_PROGRESS/DONE/BLOCKED)
        chunks/            #     01.md, 02.md, ... (LLM 자동 분해)
      cycles/<N>/          #   사이클 단위 산출물 보존
        spec.md            #     chunk 상세화 동결본
        runtime-evidence.md#     실행 증거 (필수, 미작성 시 CHECKLIST FAIL)
        qa-findings.md     #     이번 사이클 QA 이슈
        council-feedback.md#     review-council 우려
        gaps.md            #     GAP-ANALYSIS 누락분
        last-failures.md   #     CHECKLIST FAIL 항목
        gate-verifies.md   #     각 게이트 verify 통과 기록
    config/                # 문서/체크리스트 원본
      model-routing.md     #   원칙 4
      verify-checklist.md  #   원칙 1 통과 기준
      notify.md            #   Telegram chat_id + 메시지 schema 가이드
```

> 이 하네스 외부 폴더(예: `src/`, `app/`)는 **하네스가 만들어낸 실제 산출물**일 때만 추가된다. 하네스 자체 설정은 100% `.claude/` 안에 머문다.

### 역할 풀 (`.claude/agents/<role>/`)

대표님의 지시를 실행하는 직원 역할. 모든 하네스에 다음 5개 역할 폴더가 항상 깔린다.

| 역할 | 폴더 | 필수/선택 | 페르소나 (≥3 권장, 활성 시 ≥2 동시 발화) |
|------|------|-----------|-------------------------------------------|
| PM (기획) | `agents/pm/` | 필수 | strategic, user-empathic, metrics-driven |
| Dev (개발) | `agents/dev/` | 필수 | architect, pragmatist, security-paranoid |
| QA | `agents/qa/` | 필수 | edge-case, regression, ux |
| Designer | `agents/designer/` | 선택 (컨텍스트) | pixel-perfect, ux-first, contrarian |
| Marketer | `agents/marketer/` | 선택 (컨텍스트) | growth, brand, conversion |

**선택 역할은 플래그가 아니라 컨텍스트**로 활성된다 — council 스킬이 매 회의 시점에 변경 파일/도메인 키워드를 보고 활성 역할을 결정한다. UI 변경이 있으면 designer 깨우고, 카피/랜딩 변경이 있으면 marketer 깨운다.

**활성된 역할은 최소 2 페르소나가 동시 발화** (단일 시점 금지). 다양성이 6원칙의 페르소나 풀의 본래 의미.

### 루프 구조

ralph 는 **단일 연속 루프**로 돈다. 페이즈 전이는 모두 게이트이고, **모든 게이트마다 검증이 박혀 있다** (`gate-verify` 스킬).

```
[시작]
  NOT_STARTED: master-spec 미동결 → onboarding 인터뷰 (~8 질문) → master-spec 합성 → "확정" 동결
       ↓ (master-spec.frozen 생성)
  INTAKE: LLM 이 master-spec → chunk N개 분해 → manifest.md 생성 (사람 review X, 자동 통과)
       ↓
[Chunk K 사이클]
  CHUNK_DETAIL: chunk K 의 구현 방안 + 디테일 발산 (페르소나 dispatch, dispatch cap 적용)
       ↓ gate-verify(chunk_detail)
  SPEC: chunk 상세화 → spec.md 동결
       ↓ gate-verify(spec)
  ┌── IMPLEMENT ─────────────────────────────────┐ ← FAIL 시 직회귀
  │      ↓
  │  QA_REVIEW           (qa/* ≥2)
  │      ├ 이슈   → qa-findings.md   → IMPLEMENT
  │      └ clean
  │  REVIEW_COUNCIL      (수렴, 활성 역할 ≥2, dispatch cap 적용)
  │      ├ 우려   → council-feedback.md → IMPLEMENT
  │      └ PASS
  │  GAP_ANALYSIS        (pm: master-spec chunk vs 실제 산출물)
  │      ├ gaps   → gaps.md          → IMPLEMENT
  │      └ no gaps
  │  CHECKLIST           (verify-loop-output, runtime-evidence 필수)
  │      ├ FAIL   → last-failures.md → IMPLEMENT
  │      └ PASS   → CYCLE_DONE
  │                   ↓ Telegram 진척 보고 (대표님 톤)
  │              project-stop-check (모든 chunk 수용 여부 채점)
  │                   ├ 완료   → PROJECT_DONE → Telegram 완료 보고 → 대표님 검토
  │                   └ 미달   → 다음 chunk → CHUNK_DETAIL (자동)
  │
  │  [STUCK 발생 시] fail_streak ≥5 또는 deferral_count ≥3
  │      → manifest 에 BLOCKED 표기 + Telegram 개입 요청
  │      → 다음 PENDING chunk 로 우회 (ralph 멈춤 X)
```

**모든 게이트의 공통 검증 (`gate-verify`)**
- 직전 페이즈 산출물이 빈약/환각/무관 여부 확인
- master-spec chunk 의 acceptance 항목이 반영됐는지 확인
- 다음 페이즈에 필요한 입력이 빠짐없이 갖춰졌는지

상태는 `.claude/state/ralph-status.md` 에 기록. 사이클 단위 산출물은 `.claude/state/cycles/<N>/` 에 보존.

> 핵심 트레이드오프: `.claude/` 의존이 강해져서 다른 코딩 에이전트로의 이식이 어려워짐. 이 프로젝트는 "Claude Code 전용 ralph 하네스"이므로 그 비용은 수용한다.

---

## 모든 harness-ralph/<project> 가 반드시 만족할 6대 원칙

각 하위 프로젝트는 아래 6개 모듈을 반드시 포함/구현해야 한다.
모듈 누락 시 그 하네스는 미완성으로 간주.

1. **자체 검증 (self-verification)**
   - 매 루프 종료 직전 "산출물이 요구사항을 충족했는가"를 LLM이 스스로 채점.
   - runtime-evidence.md 미작성 시 CHECKLIST FAIL (fixture-driven test 만으로는 불충분).
   - 산출물: `.claude/skills/verify-loop-output/`, `.claude/config/verify-checklist.md`, Stop hook (`.claude/hooks/run-verify.sh`).

2. **상황별 동적 프롬프트 (prompt routing)**
   - 단일 시스템 프롬프트 금지. 작업 페이즈별 프롬프트 분리.
   - 산출물: `.claude/skills/phase-*/` + `.claude/commands/`.

3. **Ralph 히스토리 메모장 (durable memo)**
   - 루프 간 정보 유실 방지용 append-only 로그.
   - 위치: `.claude/state/ralph-history.md`. PostToolUse hook 이 자동 append.

4. **모델 라우팅 (cost-aware model selection)**
   - 작업 난이도/페이즈에 따라 Opus / Sonnet / Haiku 를 명시적으로 선택.
   - 각 agent frontmatter `model:` 에 박고, 결정 근거는 `.claude/config/model-routing.md` 에 문서화.

5. **배포 환경 선세팅 (deploy-first bootstrap)**
   - 코드 작성 전에 배포 파이프라인(컨테이너/Vercel/CI 등) 먼저 통과.
   - "Hello world deploy 통과" 가 첫 그린 라이트.
   - 산출물: `.claude/scripts/deploy.sh` + `.claude/scripts/smoke-test.sh`, `/ralph-deploy` 커맨드.

6. **페르소나 풀 (persona ensemble)**
   - 각 역할마다 단일 페르소나 금지. 같은 역할 내 상반된 관점의 페르소나 N개 운영.
     예) 디자이너 → {비판적, 낙관적, 픽셀 perfectionist, UX 우선, 브랜드 우선}
   - 페르소나 정의는 `.claude/agents/persona-<role>-<variant>.md`. 리뷰/검증 단계에서 다중 페르소나 agent 가 병렬 평가.
   - 모든 페르소나는 "대표님 호칭 + 보고체 톤" 으로 동작.

---

## 신규 하네스 생성 시 체크리스트

- [ ] 위 "하네스 표준 레이아웃" 의 `.claude/` 하위 폴더가 전부 존재한다
- [ ] `.claude/agents/` 에 persona ≥ 2 (역할당) 존재, 모두 "대표님" 호칭 포함
- [ ] `.claude/skills/` 에 verify 스킬 + 페이즈별 프롬프트 스킬 + onboarding + phase-intake + chunk-detail + notify-sender 존재
- [ ] `.claude/hooks/` + `.claude/settings.json` 으로 히스토리 append + 검증 자동화가 걸려 있다
- [ ] 각 agent 정의에 `model:` 필드가 명시되어 있다 (Opus / Sonnet / Haiku 중)
- [ ] `.claude/scripts/` 의 deploy + smoke-test 가 1회 이상 통과 (`.claude/state/ralph-history.md` 에 `[deploy] PASS` entry)
- [ ] `.claude/config/model-routing.md`, `.claude/config/verify-checklist.md`, `.claude/config/notify.md` 가 채워져 있다
- [ ] `.claude/state/intake/master-spec.md` placeholder 가 존재한다
- [ ] CLAUDE.md / README 에 "원칙 N → 이 프로젝트에서 어떻게 구현했는가" 매핑 표가 있다
