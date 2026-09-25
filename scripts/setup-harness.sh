#!/usr/bin/env bash
# scripts/setup-harness.sh
#
# /setup-harness 슬래시가 호출하는 본체. 현재 디렉토리에 롱러닝 하네스를 설치한다.
#
# 사용:
#   setup-harness.sh                    # clean — 빈 디렉토리(또는 하네스 파일이 없는 디렉토리)
#   setup-harness.sh --overlay          # 기존 프로젝트 위에 설치. 기존 CLAUDE.md / settings.json 은 *.pre-harness 로 백업,
#                                       # README.md 는 건드리지 않고, .gitignore 는 필요한 줄만 덧붙인다.
#   setup-harness.sh --overlay --force  # 이미 동결(onboarded: true)된 하네스도 다시 설치
#
# 환경:
#   CLAUDE_PLUGIN_ROOT  플러그인 루트 (Claude Code 가 주입). 없으면 스크립트 위치 기준.

set -euo pipefail

MODE="clean"
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --overlay) MODE="overlay" ;;
    --force) FORCE=1 ;;
    *) echo "[err] 알 수 없는 인자: $arg" >&2; exit 2 ;;
  esac
done

if [ "$PWD" = "$HOME" ] || [ "$PWD" = "/" ]; then
  echo "[err] $PWD 는 전용 디렉토리가 아닙니다. 프로젝트 디렉토리에서 실행하십시오." >&2
  exit 2
fi

for bin in jq git; do
  command -v "$bin" >/dev/null 2>&1 || { echo "[err] $bin 이 필요합니다 (brew install $bin / apt install $bin)." >&2; exit 2; }
done

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SRC="$PLUGIN_ROOT/assets/template"
[ -d "$SRC" ] || { echo "[err] 템플릿이 없습니다: $SRC" >&2; exit 1; }

# --- 충돌 검사 -----------------------------------------------------------
CONFLICTS=()
for f in CLAUDE.md README.md .harness .claude/settings.json; do
  [ -e "$f" ] && CONFLICTS+=("$f")
done
if [ "$MODE" = "clean" ] && [ "${#CONFLICTS[@]}" -gt 0 ]; then
  echo "[err] 이미 존재하는 파일: ${CONFLICTS[*]}" >&2
  echo "       기존 프로젝트 위에 설치하려면 --overlay 옵션을 쓰십시오." >&2
  exit 1
fi

if [ "$MODE" = "overlay" ] && grep -qE '^onboarded:[[:space:]]*true' CLAUDE.md 2>/dev/null && [ "$FORCE" -eq 0 ]; then
  echo "[err] CLAUDE.md 가 이미 onboarded: true 입니다 (동결된 비전 보호)." >&2
  echo "       정말 다시 설치하려면 --overlay --force 를 쓰십시오." >&2
  exit 1
fi

backup() { # backup <path> — <path>.pre-harness (이미 있으면 타임스탬프)
  local p="$1" dst="$1.pre-harness"
  [ -e "$p" ] || return 0
  [ -e "$dst" ] && dst="$p.pre-harness.$(date -u +%Y%m%dT%H%M%S)"
  mv "$p" "$dst"
  BACKED_UP+=("$dst")
}
BACKED_UP=()

# --- 설치 ----------------------------------------------------------------
if [ "$MODE" = "clean" ]; then
  cp -R "$SRC/." .
else
  backup CLAUDE.md
  backup .claude/settings.json
  [ -d .harness ] && backup .harness
  cp "$SRC/CLAUDE.md" CLAUDE.md
  cp -R "$SRC/.harness" .harness
  mkdir -p .claude/skills
  cp "$SRC/.claude/settings.json" .claude/settings.json
  [ -e .claude/skills/.gitkeep ] || touch .claude/skills/.gitkeep
  [ -e README.md ] || cp "$SRC/README.md" README.md
  # .gitignore — 없는 줄만 덧붙임
  touch .gitignore
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    grep -qxF "$line" .gitignore || echo "$line" >> .gitignore
  done < "$SRC/.gitignore"
fi
chmod +x .harness/verify.sh .harness/bin/harness.sh

# {{PROJECT_NAME}} 치환 — sed replacement 에서 위험한 | & \ 만 escape
PROJECT_NAME=$(basename "$PWD")
ESCAPED=$(printf '%s\n' "$PROJECT_NAME" | sed -e 's/[|&\]/\\&/g')
for f in CLAUDE.md README.md; do
  [ -f "$f" ] || continue
  tmp=$(mktemp)
  sed "s|{{PROJECT_NAME}}|${ESCAPED}|g" "$f" > "$tmp" && cat "$tmp" > "$f" && rm -f "$tmp"
done

# git — 하네스는 git 이력으로 진척을 판단하므로 저장소가 필수
GIT_INIT=0
if [ ! -d .git ]; then
  git init -b main -q
  git add -A
  GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-js-ralph}" GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-harness@local}" \
  GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-js-ralph}" GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-harness@local}" \
    git commit -q -m "chore: scaffold js-ralph harness v$(tr -d '[:space:]' < "$SRC/VERSION")"
  GIT_INIT=1
fi

# --- 안내 ----------------------------------------------------------------
echo
echo "[ok] js-ralph 하네스 설치 완료 (mode: $MODE)"
echo
echo "설치된 것:"
for f in CLAUDE.md README.md .harness/verify.sh .harness/bin/harness.sh .harness/memory/MEMORY.md .claude/settings.json .claude/skills; do
  [ -e "$f" ] && echo "  + $f"
done
if [ "${#BACKED_UP[@]}" -gt 0 ]; then
  echo
  echo "백업:"
  for b in "${BACKED_UP[@]}"; do echo "  - $b"; done
fi
[ "$GIT_INIT" -eq 1 ] && { echo; echo "git: main 브랜치 초기 커밋 생성"; }
echo
echo "다음 단계:"
echo "  1. vision-intake 비전 인터뷰 (자동 시작) → '확정' 으로 동결"
echo "  2. /js-ralph:feature <기획> — 기획 한 건을 끝까지 무인 진행"
echo
