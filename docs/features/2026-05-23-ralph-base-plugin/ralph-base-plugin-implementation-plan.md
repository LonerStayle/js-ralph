---
commit_policy: per-task
---

# ralph-base-plugin 구현계획서

> **For agentic workers:** REQUIRED SUB-SKILL: Use `js-super-sub-driven` (recommended for 13+ task) or `executing-plans` (12 task 이하 권장). Steps use checkbox (`- [ ]`) syntax for tracking. 본 plan 은 12 task 라 **inline (`executing-plans`) 권장**.

**Goal:** `js-ralph` factory 저장소를 Claude Code 플러그인으로 재구성 — `/setup-ralph` 슬래시 한 번에 v3-classic 하네스 세팅 + vision-intake 자동 트리거 + ralph-loop 자동 시작 게이트.

**Architecture:** factory 안에 `.claude-plugin/` + `commands/` + `scripts/` + `assets/template/` + `skills/vision-intake/` 디렉토리로 플러그인 구조 박음. 옛 `template/` / `scripts/new-harness.sh` / `verify-v3-template.sh` 는 main 에서 제거 (`pre-plugin` 브랜치에 보존). 단일 출처 = 플러그인 안 `assets/template/`.

**Tech Stack:** Bash 5.x (macOS), Claude Code plugin schema (manifest + commands + skills), bats-core (테스트), git, sed.

**Spec inputs:**
- `ralph-base-plugin-requirements.md` — FR-1 ~ FR-7, AC-1 ~ AC-8 (CH-20260523-001, 002)
- `ralph-base-plugin-tech-design.md` — D-1 ~ D-7 결정, R-1 ~ R-9 위험, §7 테스트 전략 (CH-20260523-003)

---

## 1. 단계별 작업

### Task 1: bats 테스트 인프라 + sanity test

**Files:**
- Create: `tests/sanity.bats`

**Model**: haiku

- [ ] **Step 1: bats-core 설치 확인 (manual 1회)**

Bash:
```bash
which bats || brew install bats-core
bats --version
```
Expected: bats `1.10+` 출력. 미설치 시 brew 로 설치.

- [ ] **Step 2: sanity test 작성**

**수정 후** (new file: `tests/sanity.bats`):
```bash
#!/usr/bin/env bats

@test "bats 동작 확인" {
  run echo "ok"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}
```

- [ ] **Step 3: 실행 → PASS 확인**

Run: `bats tests/sanity.bats`
Expected: `1 test, 0 failures`

- [ ] **Step 4: commit**

```bash
git add tests/sanity.bats
git commit -m "test: bats 인프라 + sanity test"
```

---

### Task 2: plugin manifest + skeleton 디렉토리

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `commands/.gitkeep`
- Create: `scripts/.gitkeep` (기존 `scripts/` 폴더는 Task 10 에서 정리)
- Create: `assets/.gitkeep`
- Create: `skills/.gitkeep`

**Model**: haiku

- [ ] **Step 1: bats test 작성 (manifest 존재 + schema)**

**수정 후** (new file: `tests/plugin-manifest.bats`):
```bash
#!/usr/bin/env bats

@test ".claude-plugin/plugin.json 존재" {
  [ -f ".claude-plugin/plugin.json" ]
}

@test "manifest 의 name = js-ralph" {
  run jq -r .name .claude-plugin/plugin.json
  [ "$status" -eq 0 ]
  [ "$output" = "js-ralph" ]
}

@test "manifest 의 version semver 형식" {
  run jq -r .version .claude-plugin/plugin.json
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
```

- [ ] **Step 2: 실행 → FAIL 확인**

Run: `bats tests/plugin-manifest.bats`
Expected: `3 tests, 3 failures` (manifest 미생성)

- [ ] **Step 3: manifest 작성**

**수정 후** (new file: `.claude-plugin/plugin.json`):
```json
{
  "name": "js-ralph",
  "version": "0.1.0",
  "description": "Claude Code 플러그인 — v3-classic ralph 하네스 셋업 + vision-intake 비전 인터뷰 + ralph-loop 자동 시작 게이트.",
  "author": {
    "name": "Jinsup Choi",
    "email": "dlwlstjq410@gmail.com"
  }
}
```

- [ ] **Step 4: skeleton 디렉토리 stub**

```bash
mkdir -p commands scripts assets skills
touch commands/.gitkeep assets/.gitkeep skills/.gitkeep
# scripts/ 폴더는 이미 존재 (factory 의 scripts/) — .gitkeep 불필요
```

- [ ] **Step 5: 실행 → PASS 확인**

Run: `bats tests/plugin-manifest.bats`
Expected: `3 tests, 0 failures`

- [ ] **Step 6: commit**

```bash
git add .claude-plugin/ commands/.gitkeep assets/.gitkeep skills/.gitkeep tests/plugin-manifest.bats
git commit -m "feat: plugin manifest + skeleton 디렉토리"
```

---

### Task 3: template/ 5파일 + 부속 → assets/template/ git mv

**Files:**
- Modify (mv): `template/CLAUDE.md` → `assets/template/CLAUDE.md`
- Modify (mv): `template/PROMPT.md` → `assets/template/PROMPT.md`
- Modify (mv): `template/AGENTS.md` → `assets/template/AGENTS.md`
- Modify (mv): `template/IMPLEMENTATION_PLAN.md` → `assets/template/IMPLEMENTATION_PLAN.md`
- Modify (mv): `template/README.md` → `assets/template/README.md`
- Modify (mv): `template/.claude/settings.json` → `assets/template/.claude/settings.json`
- Modify (mv): `template/.gitignore` → `assets/template/.gitignore`
- Modify (mv): `template/VERSION` → `assets/template/VERSION`
- Modify (mv): `template/specs/.gitkeep` → `assets/template/specs/.gitkeep`
- Modify (mv): `template/.claude/skills/vision-intake/SKILL.md` → `skills/vision-intake/SKILL.md` (D-1, 플러그인 root)
- Test: `tests/assets-template.bats`

**Model**: haiku

- [ ] **Step 1: bats test 작성**

**수정 후** (new file: `tests/assets-template.bats`):
```bash
#!/usr/bin/env bats

@test "5파일 모두 assets/template/ 에 존재" {
  for f in CLAUDE.md PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md README.md; do
    [ -f "assets/template/$f" ] || { echo "missing: assets/template/$f"; return 1; }
  done
}

@test "부속 파일 (.claude/settings.json / .gitignore / VERSION / specs/.gitkeep) 존재" {
  [ -f "assets/template/.claude/settings.json" ]
  [ -f "assets/template/.gitignore" ]
  [ -f "assets/template/VERSION" ]
  [ -f "assets/template/specs/.gitkeep" ]
}

@test "VERSION 값 = 3" {
  run cat assets/template/VERSION
  [ "$(echo "$output" | tr -d '[:space:]')" = "3" ]
}

@test "vision-intake skill = 플러그인 root 의 skills/ (D-1)" {
  [ -f "skills/vision-intake/SKILL.md" ]
  # assets/template/.claude/skills/ 는 부재 (D-1: skill 단일 출처 = 플러그인 root)
  [ ! -d "assets/template/.claude/skills" ]
}

@test "CLAUDE.md 의 {{PROJECT_NAME}} placeholder 유지" {
  run grep '{{PROJECT_NAME}}' assets/template/CLAUDE.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: 실행 → FAIL 확인**

Run: `bats tests/assets-template.bats`
Expected: `5 tests, 5 failures`

- [ ] **Step 3: git mv 일괄 실행**

```bash
mkdir -p assets/template/.claude assets/template/specs skills/vision-intake
git mv template/CLAUDE.md assets/template/CLAUDE.md
git mv template/PROMPT.md assets/template/PROMPT.md
git mv template/AGENTS.md assets/template/AGENTS.md
git mv template/IMPLEMENTATION_PLAN.md assets/template/IMPLEMENTATION_PLAN.md
git mv template/README.md assets/template/README.md
git mv template/.claude/settings.json assets/template/.claude/settings.json
git mv template/.gitignore assets/template/.gitignore
git mv template/VERSION assets/template/VERSION
git mv template/specs/.gitkeep assets/template/specs/.gitkeep
git mv template/.claude/skills/vision-intake/SKILL.md skills/vision-intake/SKILL.md
# 남은 빈 디렉토리 정리
rmdir template/.claude/skills template/.claude template/specs template 2>/dev/null || true
```

- [ ] **Step 4: 실행 → PASS 확인**

Run: `bats tests/assets-template.bats`
Expected: `5 tests, 0 failures`

- [ ] **Step 5: commit**

```bash
git add -A
git commit -m "refactor: template/ → assets/template/ + skills/vision-intake (D-1)"
```

---

### Task 4: vision-intake skill 본문에 FR-7 (자동 시작 게이트) 추가

**Files:**
- Modify: `skills/vision-intake/SKILL.md` (직전 Task 3 에서 이동된 파일)
- Test: `tests/vision-intake-fr7.bats`

**Model**: sonnet (Korean prose 조작 — Haiku rephrasing risk)

- [ ] **Step 1: bats test 작성 (FR-7 흔적 확인)**

**수정 후** (new file: `tests/vision-intake-fr7.bats`):
```bash
#!/usr/bin/env bats

@test "FR-7 게이트 문구 존재" {
  run grep 'ralph-loop 를 지금 자동 시작할까요' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}

@test "고정 prompt 인자 명시 (R-4)" {
  run grep 'Read PROMPT.md and follow it.' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}

@test "completion-promise PROJECT_DONE 명시" {
  run grep 'completion-promise.*PROJECT_DONE' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}

@test "ralph-loop path 사전 체크 안내 (D-6)" {
  run grep '플러그인 미설치' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}

@test "max-iterations 추출 로직 (D-5)" {
  run grep -E 'max-iterations.*(150|cap|추출)' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: 실행 → FAIL 확인**

Run: `bats tests/vision-intake-fr7.bats`
Expected: `5 tests, 5 failures`

- [ ] **Step 3: 5단계 동결 절차 끝에 6단계 (자동 시작 게이트) 추가**

**원본** (`skills/vision-intake/SKILL.md:102-110`, "5단계 — 동결 트리거" 의 끝 부분):
```markdown
2. 대표님께 안내:
   ```
   대표님, CLAUDE.md 가 동결되었습니다.
   이제 ralph-loop 를 시작해 주시면 자율 진행하겠습니다.

     /ralph-loop:ralph-loop "Read PROMPT.md and follow it." --completion-promise "PROJECT_DONE" --max-iterations 150

   첫 iteration 에서 AGENTS.md 검증 명령이 비어 있으면 AGENTS.md 채움부터 진행합니다.
   ```
```

**수정 후**:
```markdown
2. 대표님께 안내 + 6단계 자동 시작 게이트로 전이:
   ```
   대표님, CLAUDE.md 가 동결되었습니다.
   ```

---

## 6단계 — ralph-loop 자동 시작 게이트 (FR-7)

**선행 체크** (R-3): ralph-loop 플러그인이 설치되어 있어야 자동 시작 가능. Bash 로 path 확인:

```bash
ls ~/.claude/plugins/cache/claude-plugins-official/ralph-loop/*/scripts/setup-ralph-loop.sh 2>/dev/null | head -1
```

- path 존재 안 함 → 대표님께 안내: "ralph-loop 플러그인 미설치입니다. 먼저 `/plugin install ralph-loop` 로 설치하신 후, 수동으로 슬래시 명령을 실행해 주십시오: `/ralph-loop:ralph-loop \"Read PROMPT.md and follow it.\" --completion-promise \"PROJECT_DONE\" --max-iterations 150`" — 게이트 스킵.
- path 존재 → 다음 step.

**max-iterations 자동 추출** (D-5): CLAUDE.md 의 `### 7. 규모·일정·비용 cap` 본문에서 첫 정수를 추출. 100~500 범위면 채택, 그 외 (또는 추출 실패) default 150.

```bash
MAX_ITER=$(awk '/^### 7\./{flag=1; next} /^### /{flag=0} flag' CLAUDE.md | grep -oE '[0-9]+' | head -1)
if [ -z "$MAX_ITER" ] || [ "$MAX_ITER" -lt 100 ] || [ "$MAX_ITER" -gt 500 ]; then
  MAX_ITER=150
fi
```

**게이트 발화** (AskUserQuestion 도구):

```json
{
  "question": "ralph-loop 를 지금 자동 시작할까요? (max-iterations: <MAX_ITER>)",
  "context": "yes → fresh context 로 매 iteration 재투입 시작. no → 수동 슬래시 명령 안내만.",
  "choices": [
    {"value": "yes", "label": "예 — 지금 자동 시작"},
    {"value": "no", "label": "아니오 — 나중에 수동 실행"}
  ]
}
```

**yes 처리** (R-4: 자연어 인자 절대 박지 않음, 고정 문자열만):

```bash
PROMPT_FIXED="Read PROMPT.md and follow it."
PROMISE_FIXED="PROJECT_DONE"
SETUP_PATH=$(ls ~/.claude/plugins/cache/claude-plugins-official/ralph-loop/*/scripts/setup-ralph-loop.sh 2>/dev/null | head -1)
bash "$SETUP_PATH" "$PROMPT_FIXED" --completion-promise "$PROMISE_FIXED" --max-iterations "$MAX_ITER"
```

→ Stop hook 활성. 다음 Stop 부터 `Read PROMPT.md and follow it.` 가 fresh context 로 재투입.

**no 처리**: 안내문만 노출:

```
대표님, 자동 시작 안 하셨습니다.
수동으로 시작하시려면 아래 슬래시 명령을 입력해 주십시오:

  /ralph-loop:ralph-loop "Read PROMPT.md and follow it." --completion-promise "PROJECT_DONE" --max-iterations <MAX_ITER>

중도 멈춤이 필요하시면 `/ralph-loop:cancel-ralph` 슬래시로 cancel 가능합니다.
```

   첫 iteration 에서 AGENTS.md 검증 명령이 비어 있으면 AGENTS.md 채움부터 진행합니다.
   ```
```

- [ ] **Step 4: 실행 → PASS 확인**

Run: `bats tests/vision-intake-fr7.bats`
Expected: `5 tests, 0 failures`

- [ ] **Step 5: commit**

```bash
git add skills/vision-intake/SKILL.md tests/vision-intake-fr7.bats
git commit -m "feat(vision-intake): FR-7 ralph-loop 자동 시작 게이트 + D-5 max-iterations 추출 + D-6 path 사전 체크"
```

---

### Task 5: scripts/setup-ralph.sh — 본체 bash 스크립트

**Files:**
- Create: `scripts/setup-ralph.sh`
- Test: `tests/setup-ralph.bats`

**Model**: sonnet (bash 알고리즘 + 다중 가드 + escape 정밀)

- [ ] **Step 1: bats test 시나리오 작성 (clean / overlay / 가드 케이스)**

**수정 후** (new file: `tests/setup-ralph.bats`):
```bash
#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  export PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.."
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "clean 모드 — 빈 디렉토리에서 5파일 박힘 (AC-1)" {
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  [ "$status" -eq 0 ]
  for f in CLAUDE.md PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md README.md; do
    [ -f "$f" ] || { echo "missing: $f"; return 1; }
  done
  [ -f ".claude/settings.json" ]
  [ -f ".gitignore" ]
  [ "$(cat VERSION | tr -d '[:space:]')" = "3" ]
  [ -d ".git" ]
}

@test "{{PROJECT_NAME}} 치환 (R-2 escape 안전)" {
  bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  ! grep -q '{{PROJECT_NAME}}' CLAUDE.md
  ! grep -q '{{PROJECT_NAME}}' README.md
}

@test "clean 모드 — 충돌 시 abort (AC-3)" {
  echo "existing" > PROMPT.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--overlay" ]]
  # 기존 PROMPT.md 안 건드림
  [ "$(cat PROMPT.md)" = "existing" ]
  # 나머지 파일도 안 박힘
  [ ! -f "CLAUDE.md" ]
}

@test "overlay 모드 — 충돌 파일 .v2.bak 백업 (AC-4)" {
  echo "old-claude" > CLAUDE.md
  echo "old-prompt" > PROMPT.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay
  [ "$status" -eq 0 ]
  [ -f "CLAUDE.md.v2.bak" ]
  [ "$(cat CLAUDE.md.v2.bak)" = "old-claude" ]
  [ -f "PROMPT.md.v2.bak" ]
  # v3 새 파일 박힘
  ! grep -q '{{PROJECT_NAME}}' CLAUDE.md
}

@test "overlay 비전 보호 — onboarded:true abort, --force 없음 (AC-5)" {
  echo "onboarded: true" > CLAUDE.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--force" ]]
  # 어떤 파일도 안 박힘 / 백업도 X
  [ ! -f "CLAUDE.md.v2.bak" ]
  [ ! -f "PROMPT.md" ]
}

@test "overlay --force — onboarded:true 우회 (D-3)" {
  echo "onboarded: true" > CLAUDE.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay --force
  [ "$status" -eq 0 ]
  [ -f "CLAUDE.md.v2.bak" ]
}

@test "두 번째 백업 — .v2.bak 존재 시 timestamp 접미사 (D-4)" {
  echo "v1" > CLAUDE.md
  echo "v2-old" > CLAUDE.md.v2.bak
  echo "p1" > PROMPT.md
  bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay
  # 기존 .v2.bak 보존
  [ "$(cat CLAUDE.md.v2.bak)" = "v2-old" ]
  # 두 번째 백업은 timestamp 패턴
  ls CLAUDE.md.bak.* 2>/dev/null | grep -E '\.bak\.[0-9]{8}T[0-9]{6}' || return 1
}

@test "git init skip — overlay 모드 / .git 이미 있음 (R-5)" {
  git init -b main -q
  bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  # 새로 init 안 함 — 기존 .git 그대로
  [ -d ".git" ]
  # 초기 commit 도 안 만듦 (사용자가 직접 commit)
  run git log --oneline
  [ -z "$output" ]
}

@test "HOME / / 가드 (R-9)" {
  cd "$HOME"
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "전용 디렉토리" ]]
}

@test "잘못된 인자 abort" {
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --unknown
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: 실행 → FAIL 확인**

Run: `bats tests/setup-ralph.bats`
Expected: 10 tests, 10 failures (스크립트 미작성)

- [ ] **Step 3: setup-ralph.sh 본체 작성**

**수정 후** (new file: `scripts/setup-ralph.sh`):
```bash
#!/usr/bin/env bash
# scripts/setup-ralph.sh
#
# Claude Code 플러그인 js-ralph 의 /setup-ralph 슬래시 명령이 호출하는 본체.
# 현재 디렉토리에 v3-classic ralph 하네스 (5파일 + 부속) 를 박는다.
#
# 사용:
#   bash scripts/setup-ralph.sh                  # clean 모드 (기본)
#   bash scripts/setup-ralph.sh --overlay        # 기존 충돌 파일 .v2.bak 백업 후 박음
#   bash scripts/setup-ralph.sh --overlay --force # onboarded:true 우회 (D-3)
#
# 환경:
#   ${CLAUDE_PLUGIN_ROOT}  플러그인 root (Claude Code 가 자동 주입). 없으면 스크립트 위치로 fallback.

set -euo pipefail

# --- 인자 파싱 -----------------------------------------------------------
MODE="clean"
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --overlay) MODE="overlay" ;;
    --force) FORCE=1 ;;
    *) echo "[err] 알 수 없는 인자: $arg" >&2; exit 2 ;;
  esac
done

# --- 가드: 잘못된 디렉토리 (R-9) ----------------------------------------
if [ "$PWD" = "$HOME" ] || [ "$PWD" = "/" ]; then
  echo "[err] $PWD 는 전용 디렉토리가 아닙니다. 전용 프로젝트 디렉토리에서 실행하십시오." >&2
  exit 2
fi

# --- 플러그인 root 결정 --------------------------------------------------
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SRC="$PLUGIN_ROOT/assets/template"
if [ ! -d "$SRC" ]; then
  echo "[err] assets/template/ 부재: $SRC" >&2
  exit 1
fi

# --- 충돌 검사 -----------------------------------------------------------
FIVE_FILES=(CLAUDE.md PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md README.md)
CONFLICTS=()
for f in "${FIVE_FILES[@]}"; do
  [ -e "$f" ] && CONFLICTS+=("$f")
done

if [ "$MODE" = "clean" ] && [ "${#CONFLICTS[@]}" -gt 0 ]; then
  echo "[err] 이미 존재하는 파일: ${CONFLICTS[*]}" >&2
  echo "       기존 파일 보존하려면 --overlay 옵션을 쓰십시오." >&2
  exit 1
fi

# --- onboarded:true 가드 (D-3, AC-5) -------------------------------------
if [ "$MODE" = "overlay" ] && [ -f "CLAUDE.md" ]; then
  if grep -qE '^onboarded:\s*true' CLAUDE.md && [ "$FORCE" -eq 0 ]; then
    echo "[err] CLAUDE.md 가 이미 onboarded:true 입니다 (대표님 비전 합성본 보호)." >&2
    echo "       정말 덮으려면 --force 옵션, 또는 별도 폴더에서 작업하십시오." >&2
    exit 1
  fi
fi

# --- 백업 함수 (D-4) -----------------------------------------------------
backup_file() {
  local f="$1"
  if [ ! -e "$f" ]; then return 0; fi
  if [ ! -e "${f}.v2.bak" ]; then
    mv "$f" "${f}.v2.bak"
  else
    local stamp
    stamp=$(date -u +%Y%m%dT%H%M%S)
    mv "$f" "${f}.bak.${stamp}"
  fi
}

# --- overlay 모드 — 충돌 파일 백업 --------------------------------------
if [ "$MODE" = "overlay" ]; then
  for f in "${FIVE_FILES[@]}" .gitignore VERSION; do
    backup_file "$f"
  done
  if [ -d ".claude" ] && [ ! -d ".claude.v2.bak" ]; then
    mv .claude .claude.v2.bak
  elif [ -d ".claude" ]; then
    stamp=$(date -u +%Y%m%dT%H%M%S)
    mv .claude ".claude.bak.${stamp}"
  fi
fi

# --- 5파일 + 부속 cp -----------------------------------------------------
cp -R "$SRC/." .

# --- {{PROJECT_NAME}} 치환 (R-2: sed 구분자 `|` + 안전 escape) -----------
PROJECT_NAME=$(basename "$PWD")
# sed 의 replacement 에서 `|` `&` `\` 만 위험 — 그 셋만 escape
ESCAPED=$(printf '%s\n' "$PROJECT_NAME" | sed -e 's/[|&\\]/\\&/g')
SED_INPLACE=(-i '')
if [[ "$OSTYPE" != darwin* ]]; then SED_INPLACE=(-i); fi
sed "${SED_INPLACE[@]}" "s|{{PROJECT_NAME}}|${ESCAPED}|g" CLAUDE.md README.md

# --- git init 조건 분기 (FR-4, R-5) -------------------------------------
GIT_INIT_DONE=0
if [ "$MODE" = "clean" ] && [ ! -d ".git" ]; then
  git init -b main -q
  git add .
  GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-js-ralph}" \
  GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-ralph@local}" \
  GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-js-ralph}" \
  GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-ralph@local}" \
    git commit -q -m "chore: scaffold from js-ralph v$(cat VERSION | tr -d '[:space:]')"
  GIT_INIT_DONE=1
fi

# --- stdout 안내 (FR-5) --------------------------------------------------
echo
echo "[ok] js-ralph 하네스 세팅 완료 (mode: $MODE)"
echo
echo "박힌 파일:"
for f in "${FIVE_FILES[@]}" .claude/settings.json .gitignore VERSION specs/.gitkeep; do
  [ -e "$f" ] && echo "  + $f"
done
if [ "$MODE" = "overlay" ]; then
  echo
  echo "백업된 파일 (.v2.bak 또는 .bak.<timestamp>):"
  for f in "${FIVE_FILES[@]}.v2.bak" .claude.v2.bak; do
    [ -e "$f" ] && echo "  - $f"
  done
fi
if [ "$GIT_INIT_DONE" -eq 1 ]; then
  echo
  echo "git: main 브랜치 초기 commit 1건 생성됨"
fi

echo
echo "다음 단계:"
echo "  1. vision-intake skill 자동 트리거됨 (이 슬래시 본문이 즉시 invoke)"
echo "  2. 8 질문 답변 → '확정' 발화 → CLAUDE.md 의 onboarded:true 동결"
echo "  3. vision-intake 가 FR-7 자동 시작 게이트 띄움 (ralph-loop 자동 / 수동 선택)"
echo
```

- [ ] **Step 4: chmod +x**

```bash
chmod +x scripts/setup-ralph.sh
```

- [ ] **Step 5: 실행 → PASS 확인**

Run: `bats tests/setup-ralph.bats`
Expected: `10 tests, 0 failures`

- [ ] **Step 6: commit**

```bash
git add scripts/setup-ralph.sh tests/setup-ralph.bats
git commit -m "feat: scripts/setup-ralph.sh — clean/overlay/force 모드 + 가드 (R-1~R-9) + escape (R-2)"
```

---

### Task 6: commands/setup-ralph.md — 슬래시 명령 entry

**Files:**
- Create: `commands/setup-ralph.md`
- Test: `tests/setup-ralph-command.bats`

**Model**: sonnet (Markdown frontmatter + 한글 instruction)

- [ ] **Step 1: bats test 작성**

**수정 후** (new file: `tests/setup-ralph-command.bats`):
```bash
#!/usr/bin/env bats

@test "commands/setup-ralph.md 존재" {
  [ -f "commands/setup-ralph.md" ]
}

@test "frontmatter description 존재" {
  run grep '^description:' commands/setup-ralph.md
  [ "$status" -eq 0 ]
}

@test "frontmatter argument-hint 존재" {
  run grep '^argument-hint:' commands/setup-ralph.md
  [ "$status" -eq 0 ]
}

@test "allowed-tools 에 setup-ralph.sh path 포함" {
  run grep 'CLAUDE_PLUGIN_ROOT.*scripts/setup-ralph.sh' commands/setup-ralph.md
  [ "$status" -eq 0 ]
}

@test "본문에 vision-intake invoke instruction 포함 (D-2)" {
  run grep 'vision-intake' commands/setup-ralph.md
  [ "$status" -eq 0 ]
}

@test "bash 실행 블록 (\`\`\`!) 존재" {
  run grep -c '^```!' commands/setup-ralph.md
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}
```

- [ ] **Step 2: 실행 → FAIL 확인**

Run: `bats tests/setup-ralph-command.bats`
Expected: `6 tests, 6 failures`

- [ ] **Step 3: setup-ralph.md 작성**

**수정 후** (new file: `commands/setup-ralph.md`):
````markdown
---
description: "v3-classic ralph 하네스를 현재 디렉토리에 박고 vision-intake 비전 인터뷰를 즉시 시작합니다."
argument-hint: "[--overlay] [--force]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph.sh:*)"]
---

# Setup Ralph (v3-classic 하네스 세팅)

플러그인이 동봉한 5파일 + 부속 파일을 현재 디렉토리에 박고, vision-intake skill 을 즉시 invoke 합니다.

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph.sh" $ARGUMENTS
```

세팅이 끝나면 (위 bash 가 exit 0) **즉시 다음을 수행하십시오** (D-2: vision-intake 즉시 트리거, 같은 turn 안):

1. `vision-intake` skill 을 Skill 도구로 invoke 합니다 (사용자 별도 발화 불필요).
2. vision-intake skill 본문의 1단계 "인사" → 2단계 "8 질문" 흐름이 자동 시작됩니다.
3. 5단계 "동결" + 6단계 "ralph-loop 자동 시작 게이트 (FR-7)" 까지 완주합니다.

bash 가 exit != 0 (clean 모드 충돌 / overlay 비전 보호 abort / 잘못된 디렉토리 등) 이면 vision-intake invoke 하지 마시고, stderr 에 출력된 안내문 그대로 대표님께 보고하십시오.
````

- [ ] **Step 4: 실행 → PASS 확인**

Run: `bats tests/setup-ralph-command.bats`
Expected: `6 tests, 0 failures`

- [ ] **Step 5: commit**

```bash
git add commands/setup-ralph.md tests/setup-ralph-command.bats
git commit -m "feat: commands/setup-ralph.md 슬래시 entry + vision-intake 즉시 invoke (D-2)"
```

---

### Task 7: scripts/verify-plugin.sh — 정적 검증 (11 검증 그룹)

**Files:**
- Create: `scripts/verify-plugin.sh`
- Test: `tests/verify-plugin-self.bats` (verify 자체 동작 검증)

**Model**: sonnet (다중 grep + bash 분기)

- [ ] **Step 1: bats test 작성**

**수정 후** (new file: `tests/verify-plugin-self.bats`):
```bash
#!/usr/bin/env bats

@test "verify-plugin.sh 정상 상태에서 [PASS]" {
  run bash scripts/verify-plugin.sh
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[PASS]" ]]
}

@test "manifest 의 name 가 다르면 [FAIL]" {
  cp .claude-plugin/plugin.json .claude-plugin/plugin.json.bak
  jq '.name = "wrong-name"' .claude-plugin/plugin.json > /tmp/wrong.json
  mv /tmp/wrong.json .claude-plugin/plugin.json
  run bash scripts/verify-plugin.sh
  mv .claude-plugin/plugin.json.bak .claude-plugin/plugin.json
  [ "$status" -ne 0 ]
}

@test "assets/template/CLAUDE.md 부재 시 [FAIL]" {
  mv assets/template/CLAUDE.md /tmp/_claude.md
  run bash scripts/verify-plugin.sh
  mv /tmp/_claude.md assets/template/CLAUDE.md
  [ "$status" -ne 0 ]
}

@test "skills/vision-intake/SKILL.md frontmatter name 가 다르면 [FAIL]" {
  cp skills/vision-intake/SKILL.md /tmp/_skill.md
  sed -i '' 's/^name: vision-intake/name: wrong/' skills/vision-intake/SKILL.md
  run bash scripts/verify-plugin.sh
  cp /tmp/_skill.md skills/vision-intake/SKILL.md
  [ "$status" -ne 0 ]
}

@test "옛 template/ 폴더 잔존 시 [FAIL] (Task 10 검증)" {
  mkdir -p template
  touch template/CLAUDE.md
  run bash scripts/verify-plugin.sh
  rm -rf template
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: 실행 → FAIL 확인**

Run: `bats tests/verify-plugin-self.bats`
Expected: 5 tests, 5 failures (verify 스크립트 미작성)

- [ ] **Step 3: verify-plugin.sh 작성**

**수정 후** (new file: `scripts/verify-plugin.sh`):
```bash
#!/usr/bin/env bash
# js-ralph 플러그인 정적 검증 — 11 검증 그룹
#
# 통과 기준 (tech-design §7.3 기반):
#   1. .claude-plugin/plugin.json 존재 + name=js-ralph + semver version
#   2. commands/setup-ralph.md 존재 + frontmatter 필수 키
#   3. scripts/setup-ralph.sh 존재 + chmod +x + bash shebang + set -euo pipefail
#   4. assets/template/ 5파일 + .claude/settings.json + .gitignore + VERSION (=3) + specs/.gitkeep
#   5. skills/vision-intake/SKILL.md 존재 + frontmatter name=vision-intake
#   6. assets/template/{PROMPT,AGENTS,IMPLEMENTATION_PLAN}.md = 도구 중립 (대표님 부재)
#   7. assets/template/{CLAUDE,README}.md + skills/vision-intake/SKILL.md = 대표님 존재
#   8. assets/template/CLAUDE.md = onboarded: + ### 1.~### 8. + 미입력
#   9. assets/template/.claude/settings.json = hooks 부재 + Edit(CLAUDE.md) 허용
#   10. 옛 잔재 부재: template/ / scripts/new-harness.sh / scripts/verify-v3-template.sh
#   11. skills/vision-intake/SKILL.md = FR-7 자동 시작 게이트 흔적

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
pass() { echo "  [ok] $*"; }
fail() { echo "  [FAIL] $*" >&2; FAIL=$((FAIL+1)); }

echo "=== js-ralph plugin verify ==="
echo "root: $ROOT"

# [1] manifest
echo; echo "[1] .claude-plugin/plugin.json"
mf="$ROOT/.claude-plugin/plugin.json"
if [ -f "$mf" ]; then
  pass "manifest 존재"
  name=$(jq -r .name "$mf" 2>/dev/null)
  [ "$name" = "js-ralph" ] && pass "name=js-ralph" || fail "name='$name' (expected js-ralph)"
  ver=$(jq -r .version "$mf" 2>/dev/null)
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && pass "version=$ver (semver)" || fail "version='$ver' not semver"
else
  fail "manifest 부재: $mf"
fi

# [2] commands/setup-ralph.md
echo; echo "[2] commands/setup-ralph.md"
cmd="$ROOT/commands/setup-ralph.md"
if [ -f "$cmd" ]; then
  pass "exists"
  for key in description argument-hint allowed-tools; do
    grep -q "^${key}:" "$cmd" && pass "frontmatter $key" || fail "missing frontmatter: $key"
  done
else
  fail "missing: $cmd"
fi

# [3] scripts/setup-ralph.sh
echo; echo "[3] scripts/setup-ralph.sh"
ssh="$ROOT/scripts/setup-ralph.sh"
if [ -f "$ssh" ]; then
  pass "exists"
  [ -x "$ssh" ] && pass "chmod +x" || fail "not executable"
  head -1 "$ssh" | grep -q '^#!/usr/bin/env bash' && pass "bash shebang" || fail "missing bash shebang"
  grep -q 'set -euo pipefail' "$ssh" && pass "set -euo pipefail" || fail "missing set -euo pipefail"
else
  fail "missing: $ssh"
fi

# [4] assets/template/
echo; echo "[4] assets/template/ 5파일 + 부속"
for f in CLAUDE.md PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md README.md .claude/settings.json .gitignore VERSION specs/.gitkeep; do
  [ -e "$ROOT/assets/template/$f" ] && pass "$f" || fail "missing: assets/template/$f"
done
v=$(tr -d '[:space:]' < "$ROOT/assets/template/VERSION" 2>/dev/null || echo)
[ "$v" = "3" ] && pass "VERSION=3" || fail "VERSION='$v' (expected 3)"

# [5] skills/vision-intake/SKILL.md
echo; echo "[5] skills/vision-intake/SKILL.md"
sk="$ROOT/skills/vision-intake/SKILL.md"
if [ -f "$sk" ]; then
  pass "exists"
  grep -qE "^name:[[:space:]]*vision-intake[[:space:]]*$" "$sk" && pass "frontmatter name=vision-intake" || fail "frontmatter name mismatch"
else
  fail "missing: $sk"
fi

# [6] 도구 중립 (대표님 부재)
echo; echo "[6] PROMPT/AGENTS/PLAN 도구 중립 (대표님 부재)"
for f in PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md; do
  if grep -q "대표님" "$ROOT/assets/template/$f" 2>/dev/null; then
    fail "대표님 leaked into $f"
  else
    pass "tool-neutral: $f"
  fi
done

# [7] 호칭 본거지 (대표님 존재)
echo; echo "[7] 호칭 본거지 (대표님 존재)"
for f in "assets/template/CLAUDE.md" "assets/template/README.md" "skills/vision-intake/SKILL.md"; do
  if grep -q "대표님" "$ROOT/$f" 2>/dev/null; then
    pass "대표님 in $f"
  else
    fail "대표님 missing in $f"
  fi
done

# [8] CLAUDE.md gating + placeholder
echo; echo "[8] assets/template/CLAUDE.md gating + placeholder"
ct="$ROOT/assets/template/CLAUDE.md"
grep -q "^onboarded:" "$ct" && pass "onboarded: 키" || fail "missing onboarded:"
n=$(grep -cE "^### [1-8]\." "$ct" || true)
[ "$n" = "8" ] && pass "placeholder = 8" || fail "placeholder = $n (expected 8)"
grep -q "미입력" "$ct" && pass "'미입력' 마커" || fail "missing '미입력'"

# [9] settings.json — hooks 부재 + Edit(CLAUDE.md)
echo; echo "[9] settings.json — hooks 부재 + Edit(CLAUDE.md)"
sj="$ROOT/assets/template/.claude/settings.json"
grep -q '"hooks"' "$sj" && fail "hooks 존재 (제거 필요)" || pass "no hooks"
grep -q '"Edit(CLAUDE.md)"' "$sj" && pass "Edit(CLAUDE.md) 허용" || fail "missing Edit(CLAUDE.md)"

# [10] 옛 잔재 부재
echo; echo "[10] 옛 잔재 부재 (factory 정리, FR-6)"
for p in "template" "scripts/new-harness.sh" "scripts/verify-v3-template.sh"; do
  if [ -e "$ROOT/$p" ]; then
    fail "still present: $p (제거 필요)"
  else
    pass "absent: $p"
  fi
done

# [11] vision-intake FR-7 흔적
echo; echo "[11] vision-intake FR-7 자동 시작 게이트"
grep -q "ralph-loop 를 지금 자동 시작" "$sk" && pass "FR-7 게이트 문구" || fail "FR-7 게이트 문구 부재"
grep -q "Read PROMPT.md and follow it." "$sk" && pass "R-4 고정 prompt 인자" || fail "R-4 고정 prompt 인자 부재"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "[PASS] js-ralph plugin verify ok"
  exit 0
else
  echo "[FAIL] $FAIL check(s) failed"
  exit 1
fi
```

- [ ] **Step 4: chmod +x + 실행**

```bash
chmod +x scripts/verify-plugin.sh
bash scripts/verify-plugin.sh
```
Expected: 일부 그룹은 PASS, [10] 그룹은 옛 잔재 (template/, scripts/new-harness.sh, scripts/verify-v3-template.sh) 가 아직 존재해서 FAIL. Task 10 에서 제거 후 PASS 로 전환.

- [ ] **Step 5: bats self-test 실행**

Run: `bats tests/verify-plugin-self.bats`
Expected: 일부 PASS (verify 자체 동작은 OK), Task 10 미실행 상태라 [10] 그룹 self-test 는 FAIL. Task 10 commit 후 재실행.

- [ ] **Step 6: commit**

```bash
git add scripts/verify-plugin.sh tests/verify-plugin-self.bats
git commit -m "feat: scripts/verify-plugin.sh 정적 검증 11 그룹 (§7.3)"
```

---

### Task 8: bats Integration — e2e (AC-1, AC-3, AC-4, AC-5, AC-6)

**Files:**
- Create: `tests/integration.bats`

**Model**: sonnet (bats 다중 시나리오 작성)

- [ ] **Step 1: 시나리오 작성 (각 AC 별)**

**수정 후** (new file: `tests/integration.bats`):
```bash
#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  export PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.."
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "AC-1: 빈 디렉토리 clean → 5파일+부속+git" {
  bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  for f in CLAUDE.md PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md README.md \
           .claude/settings.json .gitignore VERSION specs/.gitkeep; do
    [ -e "$f" ] || { echo "missing: $f"; return 1; }
  done
  [ -d ".git" ]
  run git -C . log --oneline
  [ -n "$output" ]
  # {{PROJECT_NAME}} 치환 확인 — basename = mktemp 디렉토리
  ! grep -q '{{PROJECT_NAME}}' CLAUDE.md
}

@test "AC-3: 5파일 중 하나 충돌 → clean abort + 안내" {
  echo "x" > PROMPT.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--overlay" ]]
  [ ! -f "CLAUDE.md" ]
}

@test "AC-4: overlay → .v2.bak 백업 + v3 박힘" {
  for f in CLAUDE.md PROMPT.md; do echo "old-$f" > "$f"; done
  mkdir -p .claude && echo "{}" > .claude/settings.json
  bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay
  [ -f "CLAUDE.md.v2.bak" ]
  [ -f "PROMPT.md.v2.bak" ]
  [ -d ".claude.v2.bak" ]
  # v3 새 박힘
  ! grep -q '{{PROJECT_NAME}}' CLAUDE.md
}

@test "AC-5: onboarded:true overlay → abort, --force 없음" {
  echo "onboarded: true" > CLAUDE.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--force" ]]
  [ ! -f "CLAUDE.md.v2.bak" ]
  [ ! -f "PROMPT.md" ]
}

@test "AC-6: factory main 단일 출처 — 옛 잔재 부재 confirm (Task 10 후)" {
  # factory 의 worktree 상태로 검증
  cd "$PLUGIN_ROOT"
  [ ! -d "template" ]
  [ ! -f "scripts/new-harness.sh" ]
  [ ! -f "scripts/verify-v3-template.sh" ]
  # pre-plugin 브랜치에서 옛 모델 확인
  run git show pre-plugin:template/CLAUDE.md
  [ "$status" -eq 0 ]
  [[ "$output" =~ "{{PROJECT_NAME}}" ]]
}
```

- [ ] **Step 2: 실행 → AC-1~4 PASS, AC-5 PASS, AC-6 는 Task 10 후 PASS**

Run: `bats tests/integration.bats`
Expected: 4/5 PASS (AC-1, AC-3, AC-4, AC-5). AC-6 는 Task 10 commit 전이라 FAIL. 그게 정상.

- [ ] **Step 3: commit**

```bash
git add tests/integration.bats
git commit -m "test: integration AC-1/3/4/5/6 (AC-6 는 Task 10 후 PASS)"
```

---

### Task 9: 옛 모델 제거 — template/ + scripts/new-harness.sh + scripts/verify-v3-template.sh

**Files:**
- Delete: `template/` (이미 Task 3 에서 5파일 mv 되어 거의 비어 있음. 남은 빈 디렉토리만 정리)
- Delete: `scripts/new-harness.sh`
- Delete: `scripts/verify-v3-template.sh`

**Model**: haiku (단순 git rm)

- [ ] **Step 1: 잔존 확인**

```bash
ls template/ 2>&1 || echo "template/ already gone"
ls scripts/
```
Expected: template/ 가 비어있거나 부재. scripts/ 는 new-harness.sh + verify-v3-template.sh + setup-ralph.sh + verify-plugin.sh.

- [ ] **Step 2: git rm**

```bash
[ -d template ] && git rm -rf template
git rm scripts/new-harness.sh
git rm scripts/verify-v3-template.sh
```

- [ ] **Step 3: verify-plugin.sh [10] 그룹 PASS 확인**

```bash
bash scripts/verify-plugin.sh
```
Expected: [10] 그룹 "absent: template / scripts/new-harness.sh / scripts/verify-v3-template.sh" 모두 PASS. 전체 [PASS] (다른 그룹도 통과 가정).

- [ ] **Step 4: integration AC-6 재실행 → PASS**

Run: `bats tests/integration.bats`
Expected: 5/5 PASS

- [ ] **Step 5: commit**

```bash
git add -A
git commit -m "chore: 옛 factory 모델 제거 (template/ + new-harness.sh + verify-v3-template.sh) — pre-plugin 브랜치에 보존"
```

---

### Task 10: factory CLAUDE.md / README.md 갱신

**Files:**
- Modify: `CLAUDE.md` (factory 메타)
- Modify: `README.md` (factory 메타)
- Test: `tests/factory-docs.bats`

**Model**: sonnet (Korean prose 재작성)

- [ ] **Step 1: bats test 작성 (성격 전환 흔적 확인)**

**수정 후** (new file: `tests/factory-docs.bats`):
```bash
#!/usr/bin/env bats

@test "CLAUDE.md: js-ralph 플러그인 개발/배포 저장소 명시" {
  run grep -E "(플러그인 개발|플러그인 배포)" CLAUDE.md
  [ "$status" -eq 0 ]
}

@test "CLAUDE.md: pre-plugin 브랜치 보존 안내" {
  run grep "pre-plugin" CLAUDE.md
  [ "$status" -eq 0 ]
}

@test "CLAUDE.md: 옛 'ralph 하네스 공장' 표현 부재" {
  run grep "ralph 하네스 공장" CLAUDE.md
  [ "$status" -ne 0 ]
}

@test "README.md: /plugin install js-ralph + /setup-ralph 빠른시작" {
  run grep "/plugin install js-ralph" README.md
  [ "$status" -eq 0 ]
  run grep "/setup-ralph" README.md
  [ "$status" -eq 0 ]
}

@test "README.md: 옛 bash scripts/new-harness.sh 참조 부재 (또는 'pre-plugin 참조' 안내만)" {
  # new-harness.sh 가 본문에 등장하면 반드시 'pre-plugin' 근처여야 함
  if grep -q "new-harness.sh" README.md; then
    grep -B2 -A2 "new-harness.sh" README.md | grep -q "pre-plugin"
  fi
}
```

- [ ] **Step 2: 실행 → FAIL 확인**

Run: `bats tests/factory-docs.bats`
Expected: 일부 FAIL (옛 본문 그대로). 일부 PASS (옛 본문에 일부 매칭).

- [ ] **Step 3: CLAUDE.md 갱신**

**원본** (`CLAUDE.md:1-9`):
```markdown
# CLAUDE.md — js-ralph factory

이 프로젝트(`js-ralph`)는 **ralph 하네스 공장**이다. 직접 ralph 실행 환경을 운영하지 않고 template + eject 스크립트만 보유한다.

새 하네스는 `template/` 을 복제하여 외부 디렉토리 `${RALPH_HOME:-$HOME/jinsup_ralph}/<name>/` 로 eject 된다. eject 된 순간 자체 git 저장소 (`git init -b main` 자동, 초기 commit 자동).

→ factory 안에는 실제 하네스 인스턴스가 살지 않는다. `harness-ralph/` 폴더는 **사용하지 않는다** (의도적으로 비어 있음).

---
```

**수정 후**:
```markdown
# CLAUDE.md — js-ralph (Claude Code 플러그인)

이 저장소(`js-ralph`)는 **Claude Code 플러그인 `js-ralph` 의 개발/배포 저장소**다. 직접 ralph 실행 환경을 운영하지 않는다.

새 ralph 하네스를 만들려면 Claude Code 에서 `/setup-ralph` 슬래시를 한 번 실행하면 된다 — 플러그인이 동봉한 5파일이 현재 디렉토리에 박히고 vision-intake 비전 인터뷰가 즉시 시작된다.

> 옛 factory 모델 (`template/` 폴더 + `bash scripts/new-harness.sh`) 은 `pre-plugin` 브랜치 (`b8fb626`) 에 통째 보존되어 있다. 필요 시 `git checkout pre-plugin` 으로 fallback 가능.

---
```

(이하 본문은 별도 step. 기존 "v3-classic" / "4 원칙" / "기본 기술 스택" 섹션은 유지 — 개발자가 플러그인 본질 이해에 여전히 유용. "factory 디렉토리 구조" 표만 새 구조로 갱신.)

- [ ] **Step 4: CLAUDE.md 의 "factory 디렉토리 구조" 표 갱신**

**원본** (`CLAUDE.md:128-146` 영역, "factory 디렉토리 구조" 섹션):
```markdown
## factory 디렉토리 구조

\`\`\`
js-ralph/
  CLAUDE.md                      이 파일 (factory 메타)
  README.md                      사람용 사용 가이드
  HANDOFF.md                     다음 세션 인수인계 (의사결정 기록)
  template/                      모든 하네스의 원본 (v3-classic)
    CLAUDE.md  PROMPT.md  AGENTS.md  IMPLEMENTATION_PLAN.md
    specs/.gitkeep
    .claude/
      settings.json
      skills/vision-intake/SKILL.md     (Claude Code 빌트인 onboarding 과 충돌 회피 위해 vision-intake 로 명명)
    VERSION                      (현재 3)
  scripts/
    new-harness.sh               template → ejected 하네스 복제 + git init
    verify-v3-template.sh        template 정적 검증
  docs/                          v2 historical + 의사결정 기록 (보존)
  harness-ralph/                 사용 안 함 (비어 있음, vestigial)
\`\`\`
```

**수정 후**:
```markdown
## 저장소 디렉토리 구조 (js-ralph 플러그인)

\`\`\`
js-ralph/
  .claude-plugin/plugin.json     플러그인 manifest (name=js-ralph)
  commands/setup-ralph.md        /setup-ralph 슬래시 entry
  scripts/
    setup-ralph.sh               하네스 박는 본체 bash
    verify-plugin.sh             플러그인 정적 검증 (11 그룹)
  assets/template/               5파일 + 부속 (현재 디렉토리에 cp 될 원본)
    CLAUDE.md  PROMPT.md  AGENTS.md  IMPLEMENTATION_PLAN.md  README.md
    .claude/settings.json
    .gitignore  VERSION (=3)  specs/.gitkeep
  skills/vision-intake/SKILL.md  비전 인터뷰 8 질문 + FR-7 자동 시작 게이트
  tests/                         bats 단위/통합 테스트
  docs/                          v2 historical + 의사결정 기록 (보존)
  HANDOFF.md                     다음 세션 인수인계
  CLAUDE.md  README.md           이 두 파일 (저장소 메타)
\`\`\`

옛 `template/` / `scripts/new-harness.sh` / `scripts/verify-v3-template.sh` 는 `pre-plugin` 브랜치에 보존.
```

- [ ] **Step 5: README.md 빠른 시작 갱신**

**원본** (`README.md:13-21`):
```markdown
### 1) 새 하네스 만들기

\`\`\`bash
bash scripts/new-harness.sh <NAME>
\`\`\`

→ `~/jinsup_ralph/<NAME>/` 로 ejected. 자체 git 저장소 (`main` 브랜치 + 초기 commit) 자동 생성.

`RALPH_HOME` 환경변수로 위치 변경 가능 (기본 `$HOME/jinsup_ralph`).
```

**수정 후**:
```markdown
### 1) Claude Code 에 플러그인 설치 (1회)

\`\`\`
/plugin install js-ralph
\`\`\`

### 2) 새 하네스 시작

```bash
mkdir ~/my-new-project && cd ~/my-new-project
claude
\`\`\`

Claude Code 안에서:

\`\`\`
/setup-ralph
\`\`\`

→ 5파일이 박히고 vision-intake 비전 인터뷰 (8 질문) 가 즉시 시작됩니다.

> 옛 흐름 (factory clone + `bash scripts/new-harness.sh`) 은 `pre-plugin` 브랜치에 보존됨 — fallback 필요 시 `git checkout pre-plugin`.
```

- [ ] **Step 6: bats 실행 → PASS 확인**

Run: `bats tests/factory-docs.bats`
Expected: 5/5 PASS.

- [ ] **Step 7: commit**

```bash
git add CLAUDE.md README.md tests/factory-docs.bats
git commit -m "docs: factory CLAUDE.md / README.md — 플러그인 개발/배포 저장소로 성격 전환"
```

---

### Task 11: 정적 검증 게이트 (전체 verify-plugin.sh PASS + bats 전체 PASS)

**Files:**
- (검증만, 코드 수정 X)

**Model**: haiku (단순 실행 + 확인)

- [ ] **Step 1: 정적 검증**

```bash
bash scripts/verify-plugin.sh
```
Expected: 마지막 줄 `[PASS] js-ralph plugin verify ok` + exit 0.

- [ ] **Step 2: 전체 bats 실행**

```bash
bats tests/
```
Expected: 모든 .bats 파일 통과. 총 ~30 tests, 0 failures.

- [ ] **Step 3: Regression — pre-plugin 브랜치 fallback 동작 확인 (manual, 별도 디렉토리)**

```bash
TMP_REG=$(mktemp -d)
git worktree add "$TMP_REG" pre-plugin
cd "$TMP_REG"
bash scripts/new-harness.sh test-regression  # RALPH_HOME=$TMP_REG/_ejected
ls "$TMP_REG/_ejected/test-regression" || ls "$HOME/jinsup_ralph/test-regression"
git worktree remove "$TMP_REG"
```
Expected: 옛 흐름이 ejected 하네스 정상 생성. fallback 보장 confirm.

- [ ] **Step 4: 검증 결과 commit (실제 변경 없음, plan 의 [검증] entry 만)**

본 task 는 코드 변경 없음. commit 없이 plan 의 변경이력 footer 에 `[검증]` entry 만 추가 (change-history skill 이 처리).

---

### Task 12: HANDOFF.md §13 추가 (본 작업 완료 기록)

**Files:**
- Modify: `HANDOFF.md` (factory root, .gitignore 처리되어 worktree 에 없음 — 메인 repo `/Users/goldenplanet/jinsup_space/js-ralph/HANDOFF.md`)

**Model**: sonnet (Korean prose)

- [ ] **Step 1: §13 작성 (본 plan 완료 시점)**

(본 step 의 실제 내용은 plan 실행 마지막에 정해짐 — 어느 commit 까지 박혔는지 + 신규 하네스 동기화 정책 등. 골격만 미리 박음.)

**수정 후** (append to `HANDOFF.md` 끝):
```markdown

---

## 13. 2026-05-23 — js-ralph 플러그인화 완료

### 13.1 변경 요약

- factory 저장소를 Claude Code 플러그인 `js-ralph` 로 재구성
- `/setup-ralph` 슬래시 한 번에 v3-classic 하네스 세팅 + vision-intake 자동 트리거 + ralph-loop 자동 시작 게이트
- 옛 `template/` / `scripts/new-harness.sh` / `scripts/verify-v3-template.sh` 는 main 에서 제거
- 옛 모델은 `pre-plugin` 브랜치 (`b8fb626`) 에 통째 보존

### 13.2 디렉토리 구조 (CLAUDE.md 참조)

`.claude-plugin/` + `commands/` + `scripts/` + `assets/template/` + `skills/vision-intake/` + `tests/`.

### 13.3 신규 하네스 동기화 정책 (변경 없음)

이미 ejected 된 8 하네스 (Nova / TtokTtok / PlanB / shortdub / chuljeun-nyang / king_of_law / ai_news_scraping / autoproducts-feature-dev) 는 마이그 안 함. 신규 하네스부터 `/setup-ralph` 사용.

### 13.4 작업 commit 흐름

(실행 후 채움 — Task 1 ~ Task 12 commit SHA 리스트)
```

- [ ] **Step 2: commit**

```bash
git add HANDOFF.md
git commit -m "docs(HANDOFF): §13 — js-ralph 플러그인화 완료 기록"
```

---

## 2. 위험 코드 지점

- `scripts/setup-ralph.sh` — **breaking**: overlay 모드가 사용자 데이터 (코드/문서/비전) 를 덮어쓸 위험. mitigation: `.v2.bak` 자동 백업 (D-4) + onboarded:true abort (D-3) + `--force` 명시 우회 경로
- `scripts/setup-ralph.sh:치환 라인` — **side-effect**: `{{PROJECT_NAME}}` sed 치환 시 디렉토리 이름의 특수문자 (`&`, `\`, `|`) 가 sed replacement 깨뜨림. mitigation: sed 구분자 `|` + `&\\` escape (R-2)
- `skills/vision-intake/SKILL.md:FR-7` — **side-effect**: FR-7 자동 시작이 ralph-loop 플러그인 미설치 시 bash fail. mitigation: D-6 path 사전 체크 + 미설치 시 게이트 스킵 + 안내 (R-3)
- `skills/vision-intake/SKILL.md:FR-7` — **breaking**: setup-ralph-loop.sh 호출 시 자연어 인자 누설 위험 (직전 사고). mitigation: prompt 인자를 고정 문자열로 박음 (변수 치환 X) (R-4)
- `scripts/setup-ralph.sh:git init 분기` — **breaking**: `git init -b main` 이 잘못된 조건에서 실행되면 기존 git history 파괴. mitigation: `clean + ! -d .git` 두 조건 AND, overlay 모드에서는 절대 git init 호출 X (R-5)
- `scripts/setup-ralph.sh:첫 라인 가드` — **breaking**: `/setup-ralph` 가 잘못된 디렉토리 (`$HOME`, `/`) 에서 호출되면 사용자 홈 오염. mitigation: 첫 가드에서 `$PWD = $HOME || /` 이면 abort (R-9)
- `commands/setup-ralph.md:body` — **side-effect**: vision-intake 즉시 invoke 실패 시 사용자 혼란. mitigation: bash exit code 분기 — exit 0 시만 invoke, exit ≠ 0 시 stderr 안내문 보고 (D-2)

`race` 카테고리는 본 plan 에 해당 항목 없음.

---

## 3. 롤백 전략

- **Code**: `git revert <Task N SHA>` 로 task 단위 revert 가능 (commit_policy: per-task). 본 plan 전체 폐기 시 `git checkout pre-plugin -- .` 로 옛 모델 통째 복구 (단 본 worktree 가 아닌 main 작업 시).
- **Worktree 자체 폐기**: `git worktree remove .worktrees/플러그인화` 후 main 의 옛 상태 유지.
- **DB / Config**: 본 plan 은 DB / config 변경 없음. 외부 시스템 영향 0.
- **이미 ejected 된 8 하네스**: 본 plan 의 범위 밖. 마이그 안 함 (기존 정책 유지). 본 plan rollback 시에도 영향 0.
- **`pre-plugin` 브랜치 보존 확인**: `git show pre-plugin:template/CLAUDE.md` 가 옛 본문 출력하면 fallback 가능. 본 plan 진행 중 `pre-plugin` 브랜치 절대 삭제 금지.

---

## 변경이력

<!-- change-history skill auto-appends entries here, oldest first -->

### [2026-05-23 11:19] [구현계획서-수정]
- **id**: CH-20260523-004
- **이유**: 신규 구현계획서 — `js-ralph` 플러그인화 작업의 task-by-task TDD 계획. PRD (CH-001, CH-002) + tech-design (CH-003) 의 FR-1~FR-7 + D-1~D-7 + R-1~R-9 전부 task 매핑.
- **무엇이**: ralph-base-plugin-implementation-plan.md 전체 — frontmatter `commit_policy: per-task`, §1 단계별 작업 12 task (Task 1 bats infra / Task 2 plugin manifest / Task 3 5파일 mv / Task 4 vision-intake FR-7 / Task 5 setup-ralph.sh / Task 6 commands/setup-ralph.md / Task 7 verify-plugin.sh / Task 8 integration bats / Task 9 옛 모델 제거 / Task 10 factory 메타 갱신 / Task 11 정적 검증 게이트 / Task 12 HANDOFF §13), §2 위험 코드 지점 7건 (breaking 3 + side-effect 4), §3 롤백 전략.
- **영향범위**: 없음 (최초 생성). verifying-spec 4축 보고서 결과: Gaps 0 (소프트 3건 AC-2/7/8 manual 검증 명시), Conflicts 0, 외부 caller 0건, bats coverage 9 파일 / ~30 test. code-pretty: 17 `**수정 후**` 블록 검사 → 0 changes (이미 깨끗). 다운스트림 = `/execute-plan` (task 1~12 실행).
- **연관 항목**: CH-20260523-001 (PRD), CH-20260523-002 (plugin 이름 정정), CH-20260523-003 (tech-design)

### [2026-05-23 11:50] [코드-수정] (batch: tasks 1..10)
- **id**: CH-20260523-005
- **이유**: js-ralph factory → Claude Code 플러그인 재구성 완료. Task 1~10 의 모든 코드 변경을 batch 로 기록 (per-task git commit 으로 audit trail 보존).
- **무엇이**: 신규 14 파일 (.claude-plugin/plugin.json, commands/setup-ralph.md, scripts/setup-ralph.sh, scripts/verify-plugin.sh, assets/template/* 9파일, skills/vision-intake/SKILL.md), tests/ 9 bats 파일, 제거 2 파일 (scripts/new-harness.sh, scripts/verify-v3-template.sh), 갱신 2 파일 (CLAUDE.md, README.md).
- **영향범위**: 본 worktree (`플러그인화` 브랜치) 전체. 외부 caller 0건 (옛 잔재 모두 제거됨). 신규 하네스는 본 플러그인 사용, 기존 8 하네스는 영향 X.
- **위험 카테고리**: breaking 3건 (R-1 overlay 손상, R-4 자연어 인자, R-5 git init 오류) + side-effect 4건 (R-2 sed escape, R-3 ralph-loop 미설치, R-6 path, R-9 잘못된 디렉토리) — 모두 setup-ralph.sh / vision-intake skill 의 가드로 mitigation 완료.
- **task별 세부 (10건)**:
  - Task 1: `tests/sanity.bats` — bats 인프라 (none) — commit: `a5e548d`
  - Task 2: `.claude-plugin/plugin.json` 외 4 stub — manifest + skeleton (none) — commit: `faed685`
  - Task 3: `template/*` → `assets/template/*` 11파일 git mv, vision-intake skill → `skills/` (none) — commit: `ddbe6af`
  - Task 4: `skills/vision-intake/SKILL.md` 6단계 자동 시작 게이트 추가 (side-effect: R-3, breaking: R-4) — commit: `79ece99`
  - Task 5: `scripts/setup-ralph.sh` 본체 + 가드 (breaking: R-1/R-5, side-effect: R-2/R-9) — commit: `8b76785`
  - Task 6: `commands/setup-ralph.md` 슬래시 entry (none) — commit: `07249a6`
  - Task 7: `scripts/verify-plugin.sh` 11 검증 그룹 (none) — commit: `3145a12`
  - Task 8: `tests/integration.bats` AC-1/3/4/5/6 e2e (none) — commit: `d2a1b87`
  - Task 9: `scripts/new-harness.sh` + `scripts/verify-v3-template.sh` git rm (side-effect: R-7 영향 없음 confirm) — commit: `fb26a65`
  - Task 10: factory `CLAUDE.md` + `README.md` 본문 갱신 (none) — commit: `bab7b8d`
- **연관 commits**: `a5e548d..bab7b8d` (10 commits)
- **변경 전/후 코드**: 생략 — `git show <SHA>` 로 조회 (per-task commit 보존)

### [2026-05-23 11:50] [검증] (task: Task 11)
- **id**: CH-20260523-006
- **이유**: 본 plan 완료 시점 최종 정적/통합 검증.
- **무엇이**: `bash scripts/verify-plugin.sh` (11 검증 그룹) + `bats tests/` (9 파일 / 40 tests). pre-plugin 브랜치 fallback 확인은 integration AC-6 의 `git show pre-plugin:template/CLAUDE.md` 로 흡수.
- **결과**: **PASS** — verify-plugin [PASS] 11/11 그룹, bats 40/40 tests.
- **연관 commit**: N/A (검증만, 코드 변경 X)
- **연관 항목**: CH-20260523-005 (batch)

### [2026-05-23 11:50] [구현계획서-수정] (task: Task 12)
- **id**: CH-20260523-007
- **이유**: HANDOFF.md §13 추가 — 본 작업 완료 인수인계.
- **무엇이**: `/Users/goldenplanet/jinsup_space/js-ralph/HANDOFF.md` (메인 repo, .gitignore 처리되어 worktree 안 추적 X). §13 신설 — 변경 요약 / 디렉토리 구조 / 신규 하네스 동기화 정책 / commit 흐름 (Task 1~10 SHA) / 최종 검증 결과 / 다음 세션 즉시 할 일 (manual 검증 + marketplace 등록 + main 머지) / 산출물 docs/ 경로.
- **영향범위**: 없음 (HANDOFF.md 는 git 추적 X, 다음 세션 fresh context 가 참조). plan commit step 5 의 `git add HANDOFF.md` 는 .gitignore 라 자동 skip.
- **연관 항목**: CH-20260523-005 (batch), CH-20260523-006 (검증)
