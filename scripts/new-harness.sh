#!/usr/bin/env bash
# Usage: scripts/new-harness.sh <name>
#
# template/ 을 ${RALPH_HOME:-$HOME/jinsup_ralph}/<name>/ 로 복제하고
# 그 위치에서 git 저장소로 초기화한다.
#
# 환경변수:
#   RALPH_HOME   하네스가 살 외부 디렉터리. 기본 ~/jinsup_ralph
#   GIT_BRANCH   초기 브랜치 이름. 기본 main

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <name>" >&2
  exit 2
fi

NAME="$1"

# 이름 sanity 체크 — 공백/슬래시 거부
if [[ ! "$NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "[err] name must match [a-zA-Z0-9_-]+ (got: $NAME)" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/template"
DEST_PARENT="${RALPH_HOME:-$HOME/jinsup_ralph}"
DEST="$DEST_PARENT/$NAME"
BRANCH="${GIT_BRANCH:-main}"

if [ ! -d "$SRC" ]; then
  echo "[err] template not found at $SRC" >&2
  exit 1
fi

if [ -e "$DEST" ]; then
  echo "[err] $DEST already exists" >&2
  exit 1
fi

mkdir -p "$DEST_PARENT"
cp -R "$SRC" "$DEST"
echo "[ok] copied template → $DEST"

# placeholder 치환 (CLAUDE.md, README.md)
if command -v gsed >/dev/null 2>&1; then SED=gsed; else SED=sed; fi
$SED -i "s/{{PROJECT_NAME}}/$NAME/g" "$DEST/CLAUDE.md" "$DEST/README.md" 2>/dev/null || \
$SED -i '' "s/{{PROJECT_NAME}}/$NAME/g" "$DEST/CLAUDE.md" "$DEST/README.md"

# git init + 초기 커밋
TEMPLATE_VERSION="$(cat "$SRC/VERSION" 2>/dev/null | tr -d '[:space:]' || echo unknown)"

cd "$DEST"
git init -b "$BRANCH" >/dev/null 2>&1 || git init >/dev/null
git add .
GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-ralph-factory}" \
GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-ralph@local}" \
GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-ralph-factory}" \
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-ralph@local}" \
  git commit -q -m "chore: scaffold from js-ralph template v$TEMPLATE_VERSION"

echo
echo "[ok] harness ejected to: $DEST"
echo "[ok] git initialized on branch '$BRANCH', initial commit created"
echo
echo "next:"
echo "  cd $DEST"
echo "  claude                       # onboarding 8 질문 → specs/vision.md 동결"
echo "  # 그 다음 AGENTS.md 의 lint/typecheck/tests 명령을 도메인에 맞게 채우고"
echo "  # 로컬에서 1회 돌려 모두 exit 0 확인"
echo "  /loop                        # ralph-loop 자율 진행 시작"
echo
echo "remote (선택):"
echo "  gh repo create $NAME --private --source=. --remote=origin --push"
