# 개발방향: ralph-base-plugin

> **For agentic workers:** This document is the technical spec (architecture, components, data, interfaces, decisions, risks, test strategy). It is anchored to `ralph-base-plugin-requirements.md` (the PRD) and consumed by `ralph-base-plugin-implementation-plan.md` (step-by-step plan). NEXT STEP: invoke `writing-plans` skill (or run `/write-plan`) to produce the implementation plan from this design. Do NOT include step-by-step implementation tasks here — those belong in the plan.
>
> **상위 PRD**: `ralph-base-plugin-requirements.md` (CH-20260523-001)
>
> **활성 토픽**: §1 아키텍처, §2 영향 컴포넌트, §5 결정+대안, §6 위험, §7 테스트 전략
> **비활성 토픽**: §3 데이터 모델 (DB/스키마 무관), §4 외부 인터페이스 (REST/event 없음) — N/A 한 줄 처리

---

## 1. 아키텍처 개요

### 1.1 한 줄 요약

현 `js-ralph` factory 저장소를 **Claude Code 플러그인 `js-ralph`** 로 재구성. 플러그인 안에 (a) `/setup-ralph` 슬래시 명령 (b) bash 세팅 스크립트 (c) 5파일 + 부속 파일이 들어있는 `assets/template/` (d) 동봉 `vision-intake` skill 을 모두 포함. 사용자는 `/plugin install` 한 번 + 빈 디렉토리에서 `/setup-ralph` 한 번이면 v3-classic 하네스 완성.

### 1.2 ASCII 흐름

```
[사용자]                                [Claude Code]                          [현재 디렉토리]

/plugin install js-ralph    ─────►   플러그인 cache 에 다운로드
                                       (~/.claude/plugins/cache/.../js-ralph/<ver>/)
                                       skills/vision-intake 자동 로드

cd ~/my-project (빈 디렉토리)
claude
/setup-ralph                  ─────►   commands/setup-ralph.md 본문 실행
                                       └─► bash scripts/setup-ralph.sh
                                              ├─ 인자 파싱 (clean / --overlay / --force)
                                              ├─ 충돌 검사 (clean 모드: 5파일 X 보장)
                                              ├─ assets/template/ → cp -R 현재 디렉토리
                                              ├─ sed {{PROJECT_NAME}} → basename(pwd)
                                              ├─ git init -b main + 초기 commit
                                              │    (clean + .git 없을 때만)
                                              └─ stdout: 박힌 파일 목록 + 다음 단계 안내
                                       Claude 가 vision-intake skill 즉시 invoke
                                       (setup-ralph.md 본문 instruction)

vision-intake (8 질문)        ─────►   사용자 답변 → Edit CLAUDE.md (비전 8 자리)

"확정" 발화                   ─────►   Edit CLAUDE.md (onboarded:true + ISO timestamp)
                                       AskUserQuestion("ralph-loop 자동 시작?", yes/no)
                                            ├─ yes → Bash setup-ralph-loop.sh 고정인자 호출
                                            │       (max-iterations: §7 cap 추출 또는 150)
                                            └─ no  → 수동 명령 안내문 출력
```

### 1.3 단일 출처 (FR-6 정합)

옛 `template/` (factory) + `scripts/new-harness.sh` 는 main 에서 제거. 옛 모델은 `pre-plugin` 브랜치 (`b8fb626`) 에 통째 보존. **진실의 단일 출처 = 플러그인 안 `assets/template/`** 하나로 단일화.

---

## 2. 영향 받는 컴포넌트/파일

### 2.1 신규 (factory 안 플러그인 구조)

| 경로 | 역할 |
|------|------|
| `.claude-plugin/plugin.json` | manifest (name=`js-ralph`, version, description, author) |
| `commands/setup-ralph.md` | 슬래시 명령 entry point (frontmatter + bash exec block + post-instruction) |
| `scripts/setup-ralph.sh` | 실제 5파일 박는 bash (인자 파싱 / 충돌 / cp / sed / git init) |
| `scripts/verify-plugin.sh` | 플러그인 무결성 정적 검증 (assets/template 5파일 존재 / skill frontmatter / manifest schema) |
| `assets/template/CLAUDE.md` | 동봉 5파일 + 부속 (현 `template/` 5파일 그대로 이전) |
| `assets/template/PROMPT.md` | 〃 |
| `assets/template/AGENTS.md` | 〃 |
| `assets/template/IMPLEMENTATION_PLAN.md` | 〃 |
| `assets/template/README.md` | 〃 |
| `assets/template/.claude/settings.json` | 〃 |
| `assets/template/.gitignore` | 〃 |
| `assets/template/VERSION` | 〃 (현 `3` 그대로) |
| `assets/template/specs/.gitkeep` | 〃 |
| `skills/vision-intake/SKILL.md` | 동봉 skill — 현 `template/.claude/skills/vision-intake/SKILL.md` 본문 + FR-7 (자동 시작 게이트) 5단계에 추가 |

### 2.2 제거 (factory 정리, FR-6)

| 경로 | 처리 |
|------|------|
| `template/` 폴더 전체 | 제거 (옛 모델은 `pre-plugin` 브랜치 보존) |
| `scripts/new-harness.sh` | 제거 |
| `scripts/verify-v3-template.sh` | 제거 (대체: `scripts/verify-plugin.sh`) |

### 2.3 갱신 (factory 메타)

| 경로 | 어떻게 |
|------|--------|
| `CLAUDE.md` | "ralph 하네스 공장" → "**js-ralph 플러그인 개발/배포 저장소**" 로 본문 갱신. 5파일 디자인 / 4 원칙 섹션 그대로 유지 (개발자에게 여전히 유용). 디렉토리 구조 표 갱신 |
| `README.md` | 빠른 시작 = `/plugin install js-ralph` + `/setup-ralph`. 옛 흐름 (factory clone + bash) 은 "옛 모델은 `pre-plugin` 브랜치 참조" 한 줄로 |
| `docs/` | 보존 (history) |
| `HANDOFF.md` | 본 작업 완료 시 §13 추가 (별도 작업) |
| `.gitignore` | 변경 없음 |

---

## 3. 데이터 모델/스키마 변경

N/A — 본 피처는 DB / 스키마 / 영구 저장소 무관. 파일 시스템 단순 cp + sed + git 만 다룸.

---

## 4. 외부 인터페이스

N/A — REST / GraphQL / webhook / 이벤트 노출 없음. Claude Code 슬래시 인터페이스 (`/setup-ralph`) + Bash 도구만 사용. 외부 시스템 호출 없음 (ralph-loop 플러그인의 `setup-ralph-loop.sh` 호출은 같은 머신 내 다른 플러그인 bash 호출이라 외부 IF 아님).

---

## 5. 핵심 결정 + 대안 비교

### D-1: vision-intake skill 의 배포 위치

| 안 | 설명 | 장점 | 단점 |
|----|------|------|------|
| **A (채택)** | 플러그인 root 의 `skills/vision-intake/SKILL.md` 동봉. 하네스 디렉토리에는 복사 X | 플러그인이 단일 출처. js-ralph 업데이트 시 skill 도 자동 갱신 | 하네스 단독 (플러그인 미설치 환경) 으로는 vision-intake 동작 X — 본 PRD 의 신규 하네스는 항상 js-ralph 가 깔린 환경에서만 시작하므로 무관 |
| B | `assets/template/.claude/skills/vision-intake/SKILL.md` 로 두고 cp 시 함께 복사 (현 factory 모델) | 하네스 독립적 | skill 두 출처 (플러그인 + 하네스). 갱신 drift 발생 |

→ **A**. 플러그인이 master 라는 본 PRD 의 핵심 원칙과 정합.

### D-2: `/setup-ralph` 가 어떻게 vision-intake 를 트리거하나

| 안 | 설명 | 장점 | 단점 |
|----|------|------|------|
| **A (채택)** | `setup-ralph.md` body 끝에 명시 instruction: "5파일 박혔습니다. 이제 `vision-intake` skill 을 invoke 해서 비전 인터뷰를 시작하세요" → Claude 가 같은 turn 에 Skill 도구로 호출 | 같은 세션에서 즉시 트리거. 사용자가 별도 발화 불필요. 확실성 100% | setup-ralph.md 본문에 instruction 한 줄 추가 필요 (간단) |
| B | CLAUDE.md 의 `onboarded: false` 를 Claude Code 의 자동 로드 + skill 자동 트리거 메커니즘에 의존 | factory 의 기존 모델 그대로 | 같은 세션에서 CLAUDE.md 자동 재로드 안 됨 → 다음 세션 열어야 트리거. UX 후퇴 |

→ **A**. PRD FR-3 의 "별도 발화 없이 인터뷰 시작" 만족.

### D-3: `--overlay` 모드에서 onboarded:true 가드 우회 옵션

| 안 | 설명 | 장점 | 단점 |
|----|------|------|------|
| **A (채택)** | `--overlay --force` 조합만 onboarded:true 우회. `--force` 없이 onboarded:true 면 abort. `--force` 시 기존 CLAUDE.md 도 `.v2.bak` 백업 후 새로 박음 | 대표님 비전 보호 + 의도적 우회 경로 | 사용자가 `--force` 의미 알아야 함 (안내문에 명시) |
| B | onboarded:true 면 무조건 abort, 우회 X (사용자가 별도 폴더에서 다시 시작) | 데이터 안전 최대 | 진짜 마이그 필요 시 (옛 비전 폐기 + 새 비전 시작) 강제로 폴더 옮겨야 함 |
| C | 무조건 덮어쓰기 | 단순 | 비전 손실 위험 |

→ **A**. 데이터 보호 + 의도적 우회 경로 둘 다 만족.

### D-4: `setup-ralph.sh` 의 `--overlay` 충돌 파일 백업 이름 정책

| 안 | 설명 |
|----|------|
| **A (채택)** | `<filename>.v2.bak` 접미사. 이미 `.v2.bak` 가 있으면 → `<filename>.bak.<ISO-timestamp>` 로 두 번째 백업 (덮어쓰기 X) |
| B | 매번 timestamp 접미사 (`<filename>.bak.<ISO>`) | 항상 unique, 단 파일 누적 증가 |
| C | 매번 `.v2.bak` 덮어쓰기 | 백업 의미 상실 |

→ **A**. PlanB 마이그 케이스 (`.v2.bak` 이미 있음) 와 정합 + 백업 손실 0.

### D-5: FR-7 의 max-iterations 자동 추출 로직

CLAUDE.md §7 "규모·일정·비용 cap" 자유 텍스트에서 숫자 추출.

| 안 | 추출 방식 |
|----|----------|
| **A (채택)** | bash 의 `grep -oE '[0-9]+'` 으로 §7 본문 첫 정수 추출. 0 또는 100 미만 / 500 초과면 default 150 으로 fallback. 추출 실패 시 default 150 |
| B | Python helper 로 정교한 NLP | 과잉 |
| C | 자동 추출 안 함, 항상 150 | 사용자 비전 §7 무시 |

→ **A**. 단순 + 합리적 fallback + 100~500 범위 가드.

### D-6: `setup-ralph.sh` 가 호출하는 `setup-ralph-loop.sh` 의 path 해석

vision-intake skill 본문 (자동 시작 게이트) 에서 ralph-loop 플러그인의 setup script 를 Bash 도구로 호출.

| 안 | path |
|----|------|
| **A (채택)** | `~/.claude/plugins/cache/claude-plugins-official/ralph-loop/*/scripts/setup-ralph-loop.sh` (glob, 현 `template/.claude/settings.json` 의 allow-list 와 동일 패턴). 단 호출 전 `ls` 로 path 존재 확인 → 없으면 게이트 띄우기 전에 사용자에게 "ralph-loop 플러그인 미설치, 먼저 `/plugin install ralph-loop`" 안내 |
| B | `${CLAUDE_PLUGIN_ROOT}` 의 상대경로 | js-ralph 플러그인 root 이라 ralph-loop 와 다른 경로. 사용 X |
| C | 환경변수로 path override | 과잉 + 사용자 부담 |

→ **A**. 단 사전 체크 + 안내로 robustness 보장.

### D-7: `assets/template/.claude/settings.json` 의 allow-list 갱신

현 `template/.claude/settings.json` 의 마지막 항목:
```
"Bash(bash ~/.claude/plugins/cache/claude-plugins-official/ralph-loop/*/scripts/setup-ralph-loop.sh:*)"
```

→ **이건 ralph-loop 직접 호출용** 이라 본 PRD 의 FR-7 (vision-intake 가 같은 path 호출) 와 자동 정합. 변경 없음.

추가 검토: js-ralph 플러그인의 `/setup-ralph` 가 한 번 실행되면 `${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph.sh` 가 호출됨. 이건 `allowed-tools` 에 박혀 있어서 별도 settings.json 갱신 불필요.

---

## 6. 위험 / 사이드이펙트 (preliminary)

| ID | 위험 | 카테고리 | 완화 |
|----|------|----------|------|
| R-1 | `--overlay` 가 사용자 데이터 (코드/문서/비전) 를 덮어쓸 위험 | **breaking** | `.v2.bak` 자동 백업 (D-4) + onboarded:true abort (D-3) + `--force` 명시 우회 경로 |
| R-2 | `{{PROJECT_NAME}}` 치환 시 디렉토리 이름의 특수문자 (공백 / 한글 / `&` `/` 등) 가 sed 식 깨뜨림 | side-effect | bash 의 `basename "$PWD"` + sed 의 `s` 명령에서 구분자를 `|` 로 사용 (slash 충돌 회피) + 값을 `printf %q` 로 escape |
| R-3 | FR-7 의 ralph-loop 자동 시작이 ralph-loop 플러그인 미설치 시 bash fail | side-effect | D-6 의 사전 path 체크 + 안내문. 게이트 자체를 건너뛰고 미설치 안내 |
| R-4 | FR-7 자동 시작이 자연어 인자 누설로 shell glob fail (직전 세션 사고 재발) | **breaking** | vision-intake skill 본문에 **고정 명령 문자열 박음** (변수 치환 X, prompt = `"Read PROMPT.md and follow it."` 그대로) + max-iterations 만 숫자 치환 |
| R-5 | `git init -b main` 이 `clean + .git 없음` 조건 외에서 잘못 실행 → 기존 git history 파괴 | **breaking** | bash 의 조건 분기 강화 — `clean` 인자 + `! -d .git` 둘 다 만족할 때만 실행. overlay 모드에서는 `git init` 절대 호출 X |
| R-6 | 플러그인 캐시 위치가 OS / Claude Code 버전 따라 달라질 위험 | side-effect | `${CLAUDE_PLUGIN_ROOT}` 환경변수 사용 (Claude Code 표준 변수, OS 무관). path hardcode 금지 |
| R-7 | factory `template/` 제거가 이미 ejected 된 8 하네스에 영향? | side-effect | 영향 없음 — ejected 하네스는 자체 git 저장소로 독립. 본 PRD 범위 밖 (PRD §5 명시) |
| R-8 | vision-intake skill 본문 갱신이 `pre-plugin` 브랜치 의 옛 skill 과 의미 차이 | side-effect | 의도된 변경. `pre-plugin` 브랜치는 historical reference 라 동기화 불필요 |
| R-9 | `/setup-ralph` 가 잘못된 디렉토리 (예: 루트 `/`, 홈 `~`) 에서 호출됨 | **breaking** | bash 첫 줄에 가드 — `$PWD` 가 `$HOME` 또는 `/` 면 abort + "전용 디렉토리에서 실행하십시오" 안내 |

`race` 카테고리는 본 피처에 해당 항목 없음 (단일 사용자 / 단일 슬래시 호출 / 동시성 없음).

---

## 7. 테스트 전략

### 7.1 Bash 단위 (scripts/setup-ralph.sh)

- 인자 파싱: `clean` (default) / `--overlay` / `--overlay --force` 3 케이스 + 잘못된 인자 (`--unknown`) abort
- 충돌 검사: 빈 디렉토리 / 1파일 있는 디렉토리 / 5파일 모두 있는 디렉토리 각각의 동작
- `{{PROJECT_NAME}}` 치환: 일반 이름 / 공백 포함 / 한글 / 특수문자 (`my&proj`) 케이스
- `git init -b main` 조건 분기: clean+.git없음 / clean+.git있음 / overlay+.git없음 / overlay+.git있음
- onboarded:true 가드 (D-3): `--force` 없을 때 abort, 있을 때 백업 후 박음

테스트 프레임: **bats** (bash automated testing system) 또는 단순 bash assert + `set -e`. 선택은 implementation-plan 영역. 추천: bats (가독성 + macOS brew install bats-core 단순).

### 7.2 Integration (실제 환경 e2e)

- **AC-1**: 빈 `/tmp/test-ralph-clean/` → `/setup-ralph` → 5파일 + .gitignore + VERSION + .claude/settings.json + git init 확인
- **AC-2**: AC-1 직후 vision-intake skill 호출 발화 ("대표님 안녕하십니까") 확인 — 이건 자동화 어려움, manual 검증
- **AC-3**: 5파일 중 하나 있는 디렉토리에서 clean → abort + 안내 메시지
- **AC-4**: 기존 5파일 + .claude/ 있는 디렉토리에서 `--overlay` → `.v2.bak` 백업 + v3 새로 박힘
- **AC-5**: CLAUDE.md 가 onboarded:true 인 디렉토리에서 `--overlay` → abort + `--force` 안내
- **AC-6**: factory main 의 `template/` / `scripts/new-harness.sh` 부재 확인 (find / git ls-tree) + `pre-plugin` 브랜치에 보존 확인 (`git show pre-plugin:template/CLAUDE.md` 가 hit)
- **AC-7/8**: vision-intake skill 동결 직후 `AskUserQuestion` 게이트 발화 확인 + yes → ralph-loop 활성 / no → 안내문만 (manual 검증)

### 7.3 정적 검증 (scripts/verify-plugin.sh — 신규)

`scripts/verify-v3-template.sh` 의 11 검증 그룹을 플러그인 구조에 맞춰 재구성:

1. `.claude-plugin/plugin.json` 존재 + name=`js-ralph` + version 매칭
2. `commands/setup-ralph.md` 존재 + frontmatter (`description`, `argument-hint`, `allowed-tools`) 검증
3. `scripts/setup-ralph.sh` 존재 + chmod +x + 첫 줄 `#!/usr/bin/env bash` + `set -euo pipefail`
4. `assets/template/` 안 5파일 + .claude/settings.json + .gitignore + VERSION (값 `3`) + specs/.gitkeep 존재
5. `skills/vision-intake/SKILL.md` 존재 + frontmatter `name: vision-intake`
6. assets/template/{PROMPT,AGENTS,IMPLEMENTATION_PLAN}.md 의 "대표님" 호칭 부재 (도구 중립 유지)
7. assets/template/{CLAUDE,README}.md + skills/vision-intake/SKILL.md 에는 "대표님" 존재
8. assets/template/CLAUDE.md 의 `onboarded:` gating 키 + `### 1.` ~ `### 8.` 8 placeholder + "미입력" 마커 존재
9. assets/template/.claude/settings.json 에 hooks 섹션 없음 + Edit(CLAUDE.md) 권한 명시
10. (제거 검증) factory 루트에 옛 `template/` / `scripts/new-harness.sh` 부재 확인
11. (FR-7 정합) skills/vision-intake/SKILL.md 본문에 "ralph-loop 자동 시작" + AskUserQuestion 게이트 텍스트 존재

### 7.4 Regression — 옛 모델 fallback

`pre-plugin` 브랜치 checkout 후 `bash scripts/new-harness.sh test-regression` 이 옛 흐름대로 동작하는지 1회 확인 (수동). 즉 옛 모델이 보존 브랜치에서 여전히 작동 가능 confirm.

---

## 변경이력

<!-- change-history skill auto-appends entries here, oldest first -->

### [2026-05-23 11:05] [개발방향-수정]
- **id**: CH-20260523-003
- **이유**: 신규 기술 설계 — js-ralph plugin 화 작업의 아키텍처 / 영향 컴포넌트 / 결정+대안 / 위험 / 테스트 전략 결정. PRD (CH-20260523-001) 의 FR-1~FR-7 + AC-1~AC-8 전부 다운스트림 매핑. plugin 이름은 본 작업에서 `ralph-base` (가칭) → **`js-ralph`** 로 확정 (CH-20260523-002 와 동시).
- **무엇이**: ralph-base-plugin-tech-design.md 전체 — §1 아키텍처 (1.1 한 줄 요약, 1.2 ASCII 흐름, 1.3 단일 출처), §2 영향 컴포넌트 (신규 14건 / 제거 3건 / 갱신 2건), §5 결정+대안 7건 (D-1 ~ D-7), §6 위험 9건 (R-1 ~ R-9: breaking 3 / side-effect 6 / race 0), §7 테스트 전략 (bash unit / integration AC-1~8 / 정적 검증 / regression). §3 데이터 모델 + §4 외부 인터페이스 = N/A 한 줄 (PRD 카테고리 b 정합).
- **영향범위**: 없음 (최초 생성). verifying-spec 4축 보고서 결과: Gaps 0 / Conflicts 0 / 외부 caller 0건 (clean delete 가능) / Test coverage = 신규 bash test 추가 필요 (§7.1).
- **연관 항목**: CH-20260523-001 (상위 PRD), CH-20260523-002 (plugin 이름 정정)
