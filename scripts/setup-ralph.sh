#!/usr/bin/env bash
# scripts/setup-ralph.sh
#
# Claude Code 플러그인 js-ralph 의 /setup-ralph 슬래시 명령이 호출하는 본체.
# 현재 디렉토리에 v3-classic ralph 하네스 (5파일 + 부속) 를 박는다.
#
# 사용:
#   bash scripts/setup-ralph.sh                    # clean 모드 (기본)
#   bash scripts/setup-ralph.sh --overlay          # 기존 충돌 파일 .v2.bak 백업 후 박음
#   bash scripts/setup-ralph.sh --overlay --force  # onboarded:true 우회 (D-3)
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
  if grep -qE '^onboarded:[[:space:]]*true' CLAUDE.md && [ "$FORCE" -eq 0 ]; then
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
ESCAPED=$(printf '%s\n' "$PROJECT_NAME" | sed -e 's/[|&\]/\\&/g')
if [[ "$OSTYPE" == darwin* ]]; then
  sed -i '' "s|{{PROJECT_NAME}}|${ESCAPED}|g" CLAUDE.md README.md
else
  sed -i "s|{{PROJECT_NAME}}|${ESCAPED}|g" CLAUDE.md README.md
fi

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
  for f in "${FIVE_FILES[@]/%/.v2.bak}" .claude.v2.bak; do
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
echo "  3. vision-intake 가 FR-7 자동 시작 게이트 띄움 (goal 루프 자동 / 수동 선택)"
echo
