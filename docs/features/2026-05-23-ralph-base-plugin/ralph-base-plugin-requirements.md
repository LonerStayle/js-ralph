# 요구사항: ralph-base-plugin

> **For agentic workers:** This document is the PRD (planning-level only). NEXT STEP: invoke `designing-direction` skill (or run `/design`) to produce `<slug>-tech-design.md` from this document. Do NOT add tech decisions or implementation details here — those belong in the next two artifacts.
>
> **Category:** (b) 내부 도구 / 스크립트 — Claude Code 플러그인 배포물. 사용자 스토리 / NFR 스킵, 범위 밖 / 수용 기준 간소화.

---

## 1. 배경/목적

### 1.1 현재 (factory 모델)

- 새 ralph 하네스는 `js-ralph` factory 저장소를 clone → `bash scripts/new-harness.sh <NAME>` → `~/jinsup_ralph/<NAME>/` 로 eject. 사용자가 factory 저장소 자체를 갖고 있어야 한다.
- template/ 5파일 + `.claude/skills/vision-intake/` + `.claude/settings.json` + `.gitignore` + `VERSION` 이 매번 ejected 하네스로 복사된다.
- factory 갱신은 신규 eject 부터만 자동 적용된다. 이미 ejected 된 8 하네스 (Nova / TtokTtok / PlanB / shortdub / chuljeun-nyang / king_of_law / ai_news_scraping / autoproducts-feature-dev) 는 동기화 안 됨 — 옛 skill 이름 `onboarding/` 그대로 남아 빌트인과 충돌하는 케이스가 이미 발생.

### 1.2 목적

Claude Code 플러그인 `js-ralph` (가칭) 한 번 설치 → 어느 디렉토리에서든 `/setup-ralph` 슬래시 한 번에 v3-classic 하네스 세팅 + vision-intake 자동 트리거.

### 1.3 부수 효과

- factory `scripts/new-harness.sh` 가 deprecate 됨 (즉시 제거 X — `pre-plugin` 브랜치에 보존)
- template 단일 출처가 factory → 플러그인으로 이동
- 신규 하네스의 위치 자유 (`~/jinsup_ralph/` 강제 X)
- 플러그인 업데이트가 모든 신규 하네스에 즉시 반영
- factory 갱신과 ejected 하네스 사이의 drift 문제 자체 소멸 (새 하네스마다 최신 플러그인이 작동)

---

## 2. 사용자 스토리 / 시나리오

해당 없음 — 내부 도구라 외부 사용자 없음 (사용자 = 대표님 본인 + 가까운 협업자).

---

## 3. 기능 요구사항 (FR)

### FR-1: `/setup-ralph` (clean 모드, 기본)

- 현재 디렉토리에 5파일 (CLAUDE.md / PROMPT.md / AGENTS.md / IMPLEMENTATION_PLAN.md / README.md) 중 하나라도 이미 있으면 abort + "--overlay 모드 쓰십시오" 안내. abort 시 어떤 파일도 안 박음.
- 충돌 없으면 박는 것:
  - 5파일 (CLAUDE.md / PROMPT.md / AGENTS.md / IMPLEMENTATION_PLAN.md / README.md)
  - `.claude/settings.json`
  - `.gitignore`
  - `VERSION` (현재 3)
  - `specs/.gitkeep`
- CLAUDE.md / README.md 의 `{{PROJECT_NAME}}` placeholder 는 현재 디렉토리 basename 으로 자동 치환.

### FR-2: `/setup-ralph --overlay` (overlay 모드)

- 기존 5파일 중 충돌하는 것만 `<filename>.v2.bak` 접미사로 mv 후 v3 박음.
- `.claude/` 디렉토리가 이미 있으면 `.claude.v2.bak/` 로 mv 후 새로 박음 (settings.json 도 새것으로).
- **CLAUDE.md 가 이미 `onboarded: true` 상태면 abort** + 안내 ("대표님 비전이 합성되어 있습니다. 정말 덮을지 명시적 `--force` 옵션을 주십시오 — 또는 별도 폴더에 박으십시오"). 비전 자동 마이그는 본 플러그인 범위 밖.
- `.gitignore` / `VERSION` 도 동일 패턴 (`.v2.bak` 백업 후 새로).

### FR-3: vision-intake skill 자동 트리거

- 세팅 완료 후, 박힌 CLAUDE.md 의 `onboarded: false` 상태가 Claude Code 의 자동 로드 + skill 트리거 메커니즘에 의해 vision-intake skill 을 호출하도록 한다.
- 슬래시 명령 자체가 vision-intake 를 즉시 invoke 하는 것도 옵션 — 어느 쪽이든 사용자가 별도 발화 ("vision-intake 시작해줘") 없이 인터뷰가 시작되는 것이 요구사항.

### FR-4: git init 자동 (clean 모드 한정)

- clean 모드 + 현재 디렉토리에 `.git` 없으면 → `git init -b main` + 5파일 + 부속 파일 `git add` + 초기 commit (`chore: scaffold from js-ralph v<VERSION>`).
- overlay 모드 또는 `.git` 이미 있으면 skip — 사용자가 기존 git history 에 자기 commit 으로 박음.

### FR-5: 슬래시 종료 후 안내 메시지

세팅 완료 시 사용자에게 한 화면으로:

1. 무엇이 박혔는지 (clean / overlay / 백업된 파일 목록)
2. 다음 단계: "vision-intake 가 자동 트리거됩니다. 8 질문 답변 → '확정' 발화 → `onboarded: true` 동결 → ralph-loop 자동 시작 게이트 (FR-7)"

### FR-6: factory 정리 + 단일 출처 전환

옛 모델은 `pre-plugin` 브랜치 (`b8fb626`) 에 통째 보존되어 있으므로 main 의 중복 자산은 본 작업에서 함께 제거. 정보 손실 0.

| 대상 | 처리 |
|------|------|
| `template/` 폴더 (5파일 + .claude/skills/vision-intake + settings.json + .gitignore + VERSION + specs/) | **제거**. 플러그인 안 5파일이 단일 출처 |
| `scripts/new-harness.sh` | **제거**. 플러그인의 `/setup-ralph` 가 대체 |
| `scripts/verify-v3-template.sh` | **제거** 또는 플러그인 안으로 이동 — 검증 대상이 플러그인 안 5파일로 옮겨가므로 (위치는 tech-design 영역) |
| `CLAUDE.md` / `README.md` | "이제 `js-ralph` 플러그인 사용. 옛 factory 모델은 `pre-plugin` 브랜치 참조" 로 본문 갱신 |
| `docs/` / `HANDOFF.md` | 그대로 보존 (history / 인수인계) |
| (신규) 플러그인 소스 자체 | factory 저장소 안 `.claude-plugin/` 류 폴더에서 개발/배포 — manifest + 동봉 5파일 + 동봉 vision-intake skill (실제 디렉토리 구조는 tech-design 영역) |

→ factory 저장소 성격 변경: **ralph 하네스 공장 → js-ralph 플러그인 개발/배포 저장소**.

### FR-7: vision-intake 종료 직후 ralph-loop 자동 시작 게이트

vision-intake skill 이 "확정" 발화 처리 + `onboarded: true` 박은 직후, 사용자에게 1회 게이트:

- `AskUserQuestion("ralph-loop 를 지금 자동 시작할까요?", choices=[yes / no])`
- **yes**: vision-intake skill 본문이 Bash 도구로 `setup-ralph-loop.sh` 를 **고정 인자** 로 호출 → Stop hook 자동 활성화 → 다음 Stop 부터 fresh context 로 매 iteration 재투입. 사용자가 슬래시 명령을 직접 입력하지 않음. **자연어 인자는 절대 박지 않음** (직전 세션에서 자연어 인자 박아 shell glob 으로 fail + 의도치 않은 loop 활성화 사고 발생).
- **no**: 안내문만 노출 (수동 실행용 슬래시 명령 한 줄 + cancel 방법).

**고정 호출 명세**:
- prompt: `"Read PROMPT.md and follow it."`
- completion-promise: `"PROJECT_DONE"`
- max-iterations: 기본 `150` (CLAUDE.md 의 비전 §7 "규모·일정·비용 cap" 에서 명시값 추출 가능하면 그 값 우선 — 추출 로직은 tech-design 영역)

**영향 범위**: 본 PRD 가 js-ralph 플러그인이 자체 동봉할 `vision-intake` skill 본문도 함께 갱신함을 명시한다 — 현재 `template/.claude/skills/vision-intake/SKILL.md` 의 "5단계 동결 실행 절차" 끝에 본 게이트를 추가.

---

## 4. 비기능 요구사항 (NFR)

해당 없음 — 내부 도구라 성능/가용성 메트릭 의미 적음. 안전 관련 가드만 FR 안에 명시 (FR-1 의 충돌 abort, FR-2 의 onboarded:true abort).

---

## 5. 범위 밖 (Out of Scope)

대화 중 명시 + 추가 정리:

- **이미 ejected 된 8 하네스의 마이그레이션** — 본 플러그인 적용 안 함. 신규 하네스부터. (HANDOFF.md §1.3.1 의 기존 정책 그대로)
- **ralph-loop 플러그인과의 통합** — 별도 플러그인 그대로. 사용자가 `/plugin install ralph-loop` 별도 1회. js-ralph 플러그인은 ralph-loop 의 `setup-ralph-loop.sh` 경로를 직접 호출만 함 (FR-7) — 본체 수정 X.
- **vision-intake skill 본문 수정은 본 PRD 범위 안** (FR-7) — 단, 비전 인터뷰 8 질문 catalog 자체는 변경 X. 마지막 동결 단계 끝에 자동 시작 게이트만 추가.
- **CLAUDE.md 비전 자동 마이그** (PlanB 케이스처럼 `.claude.v2.bak/state/intake/master-spec.md` → 새 CLAUDE.md 8 자리로 옮김) — overlay 모드 가드만 박고 (FR-2 의 onboarded:true abort), 실제 마이그는 사용자가 ralph 한테 자연어로 지시.
- **플러그인 marketplace 공개 등록** — 일단 로컬/팀 dev plugin 으로만. 공개 등록은 별도 결정.
- **Windows / Linux 지원** — macOS (darwin) 기준만. factory 가 이미 `gsed` 등 darwin 가정 — 플러그인도 동일.
- **새로운 ralph 행동 규칙** — PROMPT.md 본문은 현재 v3-classic 그대로. 행동 변경 없음. 본 작업은 배포/세팅 메커니즘만 변경.
- **template 5파일 내용 변경** — 본 작업 범위 밖. 5파일 내용 변경이 필요하면 별도 PR.
- ~~factory `template/` 즉시 제거 — 한동안 보존~~ → **본 작업에서 함께 제거** (FR-6 으로 이동). 옛 모델은 `pre-plugin` 브랜치에 통째 보존.

---

## 6. 수용 기준 (Acceptance Criteria)

- **AC-1 (clean 정상 경로)**: 빈 디렉토리 `~/test-ralph-clean/` 에서 `/setup-ralph` → 5파일 + `.claude/settings.json` + `.gitignore` + `VERSION=3` + `specs/.gitkeep` 박힘. CLAUDE.md / README.md 의 `{{PROJECT_NAME}}` = `test-ralph-clean` 치환됨. `.git/` 생성 + main 브랜치 + 초기 commit 1건.
- **AC-2 (vision-intake 자동 트리거)**: AC-1 직후 (또는 같은 슬래시 세션 끝에) vision-intake skill 이 호출되어 "대표님 안녕하십니까. ralph 입니다. 프로젝트를 시작하기 전에 8가지 질문을 드리겠습니다." 첫 줄이 발화됨.
- **AC-3 (clean abort)**: 5파일 중 하나 (예: `PROMPT.md`) 가 이미 있는 디렉토리에서 `/setup-ralph` (clean) → 아무것도 안 박힘 + "이미 PROMPT.md 가 있습니다. `/setup-ralph --overlay` 를 사용하십시오" 안내.
- **AC-4 (overlay 정상)**: 기존 5파일 + `.claude/` 있는 디렉토리 (예: PlanB 시뮬레이션) 에서 `/setup-ralph --overlay` → 충돌 파일들이 `.v2.bak` 접미사로 mv 됨, v3 5파일 + `.claude/` 새로 박힘.
- **AC-5 (overlay 비전 보호)**: CLAUDE.md 가 `onboarded: true` 인 디렉토리에서 `/setup-ralph --overlay` → abort + "대표님 비전 합성본 보호 — `--force` 또는 별도 폴더 사용 안내". 어떤 파일도 안 박힘.
- **AC-6 (factory 단일 출처 전환 완료)**: factory main 에서 `template/` / `scripts/new-harness.sh` 가 제거됨. `scripts/verify-v3-template.sh` 도 제거 또는 플러그인 안으로 이동됨. factory `CLAUDE.md` / `README.md` 본문이 "js-ralph 플러그인 사용" + "pre-plugin 브랜치에 옛 모델 보존" 으로 갱신됨. `pre-plugin` 브랜치 (`b8fb626`) 가 옛 모델 전체 보존 confirm.
- **AC-7 (ralph-loop 자동 시작 — yes)**: vision-intake 종료 후 게이트에서 "yes" 답 → `setup-ralph-loop.sh` 가 고정 인자로 호출됨 + `.claude/ralph-loop.local.md` 가 생성됨 + Stop hook 활성. 다음 Stop 부터 `Read PROMPT.md and follow it.` 가 fresh context 로 재투입.
- **AC-8 (ralph-loop 수동 — no)**: 게이트에서 "no" 답 → 어떤 명령도 실행되지 않음 + 수동 실행용 슬래시 한 줄 + `/ralph-loop:cancel-ralph` 로 멈출 수 있다는 안내 노출.

---

## 변경이력

<!-- change-history skill auto-appends entries here, oldest first -->

### [2026-05-23 10:38] [요구사항-수정]
- **id**: CH-20260523-001
- **이유**: 신규 피처 brainstorming 결과 — js-ralph factory 의 ralph 하네스 생성 메커니즘을 Claude Code 플러그인 (`js-ralph`) 으로 전환. 옛 factory 모델 (template + scripts/new-harness.sh) 는 `pre-plugin` 브랜치 (`b8fb626`) 에 보존됨.
- **무엇이**: ralph-base-plugin-requirements.md 전체 — §1 배경/목적, §3 기능 요구사항 (FR-1 ~ FR-7), §5 범위 밖, §6 수용 기준 (AC-1 ~ AC-8). §2 사용자 스토리 + §4 비기능 요구사항 = "해당 없음" (카테고리 b 내부 도구).
- **영향범위**: 없음 (최초 생성). 다운스트림 `ralph-base-plugin-tech-design.md` 는 designing-direction 에서 생성 예정.

### [2026-05-23 11:05] [요구사항-수정]
- **id**: CH-20260523-002
- **이유**: 플러그인 이름 명세 — 대표님 지적으로 `ralph-base` (가칭) → **`js-ralph`** (factory 저장소명과 통일). 피처 slug `ralph-base-plugin` 은 그대로 유지 (피처 식별자 vs 배포 식별자 의도적 분리).
- **무엇이**: 본문 7건 plugin 이름 참조 일괄 치환 — §1.2 (목적), §3 FR-4 (commit msg `chore: scaffold from js-ralph v<VERSION>`), §3 FR-6 (factory 갱신 표), §3 FR-7 (영향 범위), §5 (out-of-scope ralph-loop 통합), §6 AC-6, CH-20260523-001 의 이유 라인. 슬러그 패턴 `ralph-base-plugin` 은 Python regex `\bralph-base(?!-plugin)` negative-lookahead 로 보호됨.
- **영향범위**: tech-design.md 의 plugin 이름 참조 11건 동시 갱신 (CH-20260523-003 으로 별도 기록). verifying-spec 보고서 결론 변화 없음 — 의미적 변경 X, 식별자만.
- **연관 항목**: CH-20260523-001 (정정 대상), CH-20260523-003 (tech-design 동시 갱신)
