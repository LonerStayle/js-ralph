#!/usr/bin/env bash
# js-ralph 플러그인 정적 검증 — 11 검증 그룹 (tech-design §7.3)

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
  pass "manifest exists"
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
for f in CLAUDE.md PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md README.md \
         .claude/settings.json .gitignore VERSION specs/.gitkeep; do
  [ -e "$ROOT/assets/template/$f" ] && pass "$f" || fail "missing: assets/template/$f"
done
v=$(tr -d '[:space:]' < "$ROOT/assets/template/VERSION" 2>/dev/null || echo)
[ "$v" = "3" ] && pass "VERSION=3" || fail "VERSION='$v' (expected 3)"

# [5] skills/vision-intake/SKILL.md
echo; echo "[5] skills/vision-intake/SKILL.md"
sk="$ROOT/skills/vision-intake/SKILL.md"
if [ -f "$sk" ]; then
  pass "exists"
  grep -qE "^name:[[:space:]]*vision-intake[[:space:]]*$" "$sk" \
    && pass "frontmatter name=vision-intake" \
    || fail "frontmatter name mismatch"
else
  fail "missing: $sk"
fi

# [6] 도구 중립
echo; echo "[6] PROMPT/AGENTS/PLAN 도구 중립 (대표님 부재)"
for f in PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md; do
  if grep -q "대표님" "$ROOT/assets/template/$f" 2>/dev/null; then
    fail "대표님 leaked into $f"
  else
    pass "tool-neutral: $f"
  fi
done

# [7] 호칭 본거지
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

# [9] settings.json
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

# [11] FR-7 자동 시작 게이트 흔적
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
