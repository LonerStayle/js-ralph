#!/usr/bin/env bash
# .harness/verify.sh — 결정적 검증 게이트 (backpressure).
#
# 노드를 done 으로 바꾸거나 commit 하기 전에 반드시 이 스크립트가 exit 0 이어야 한다.
# LLM 판단으로 통과시키지 않는다. 이 스크립트가 유일한 합격 기준이다.
#
# 동작:
#   1) 스택 자동 탐지 — 루트와 1단계 하위 디렉토리에서
#        pyproject.toml → (ruff / mypy 가 선언돼 있으면) + pytest
#        package.json   → 정의된 lint / typecheck / test 스크립트
#        gradlew        → ./gradlew check
#   2) .harness/verify.d/*.sh — 프로젝트 고유 추가 검증 (전부 exit 0 이어야 함)
#
# 규칙:
#   - 스택이 하나도 탐지되지 않고 verify.d 도 비어 있으면 실패한다 (검증 없는 통과 금지).
#   - 이 파일과 verify.d 의 기존 파일은 onboarded 이후 에이전트가 수정/삭제할 수 없다 (hook 이 차단).
#     검증을 늘리려면 verify.d/ 에 새 파일을 추가한다. 추가만 가능하고 약화는 불가능하다.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FAIL=0
RAN=0

step() { # step <설명> <디렉토리> <명령...>
  local desc="$1" dir="$2"; shift 2
  RAN=$((RAN+1))
  echo "── [$desc] ($dir) $*"
  if (cd "$dir" && CI=true "$@"); then
    echo "   ok"
  else
    echo "   FAIL: $desc ($dir)" >&2
    FAIL=$((FAIL+1))
  fi
}

candidate_dirs() {
  echo "."
  find . -mindepth 1 -maxdepth 1 -type d \
    ! -name '.*' ! -name node_modules ! -name venv ! -name build ! -name dist \
    | sed 's|^\./||' | sort
}

has_script() { # package.json 에 scripts.<name> 이 있는지
  jq -e --arg s "$1" '.scripts[$s] // empty' "$2/package.json" >/dev/null 2>&1
}

py_run() { # uv 가 있으면 uv run, 없으면 python -m
  if command -v uv >/dev/null 2>&1; then echo "uv run"; else echo "python3 -m"; fi
}

for d in $(candidate_dirs); do
  if [ -f "$d/pyproject.toml" ]; then
    R=$(py_run)
    grep -q 'ruff' "$d/pyproject.toml" && step "python lint" "$d" $R ruff check .
    grep -q 'mypy' "$d/pyproject.toml" && step "python typecheck" "$d" $R mypy .
    step "python tests" "$d" $R pytest -q
  fi
  if [ -f "$d/package.json" ]; then
    command -v jq >/dev/null 2>&1 || { echo "jq 필요" >&2; exit 2; }
    has_script lint "$d" && step "node lint" "$d" npm run --silent lint
    has_script typecheck "$d" && step "node typecheck" "$d" npm run --silent typecheck
    if has_script test "$d"; then
      step "node tests" "$d" npm run --silent test
    else
      echo "   FAIL: $d/package.json 에 test 스크립트가 없습니다" >&2; FAIL=$((FAIL+1))
    fi
  fi
  if [ -x "$d/gradlew" ]; then
    step "gradle check" "$d" ./gradlew check --console=plain -q
  fi
done

for f in .harness/verify.d/*.sh; do
  [ -f "$f" ] || continue
  step "extra $(basename "$f")" "." bash "$f"
done

echo
if [ "$RAN" -eq 0 ]; then
  echo "[verify] FAIL — 검증할 스택을 찾지 못했습니다. 스택을 스캐폴딩하고 테스트를 최소 1개 추가하십시오." >&2
  exit 1
fi
if [ "$FAIL" -eq 0 ]; then
  echo "[verify] PASS ($RAN checks)"
  exit 0
fi
echo "[verify] FAIL ($FAIL / $RAN checks failed)" >&2
exit 1
