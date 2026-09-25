#!/usr/bin/env bash
# js-ralph 플러그인 정적 검증 (v2 — 롱러닝 하네스)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$ROOT/assets/template"
FAIL=0
pass() { echo "  [ok] $*"; }
fail() { echo "  [FAIL] $*" >&2; FAIL=$((FAIL+1)); }
need() { [ -e "$ROOT/$1" ] && pass "$1" || fail "missing: $1"; }

echo "=== js-ralph plugin verify ==="

echo; echo "[1] manifest"
mf="$ROOT/.claude-plugin/plugin.json"; mk="$ROOT/.claude-plugin/marketplace.json"
[ "$(jq -r .name "$mf")" = "js-ralph" ] && pass "name=js-ralph" || fail "plugin name"
ver=$(jq -r .version "$mf")
[[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && pass "version=$ver" || fail "version '$ver' not semver"
[ "$(jq -r '.plugins[0].version' "$mk")" = "$ver" ] && pass "marketplace version sync" || fail "marketplace version != $ver"
[ "$(jq -r '.plugins[0].source.ref' "$mk")" = "v$ver" ] && pass "marketplace ref=v$ver" || fail "marketplace ref != v$ver"

echo; echo "[2] commands"
for c in setup-harness feature resume pause status; do
  f="commands/$c.md"; need "$f"
  grep -q '^description:' "$ROOT/$f" 2>/dev/null || fail "$f: description frontmatter"
done

echo; echo "[3] agents"
for a in planner builder reviewer curator; do
  f="agents/$a.md"; need "$f"
  grep -qE "^name:[[:space:]]*$a[[:space:]]*$" "$ROOT/$f" 2>/dev/null || fail "$f: name frontmatter"
  grep -q '^description:' "$ROOT/$f" 2>/dev/null || fail "$f: description frontmatter"
  grep -q '^tools:' "$ROOT/$f" 2>/dev/null || fail "$f: tools frontmatter"
done
# reviewer 는 읽기 전용이어야 함 (판정자가 코드를 고치면 안 됨)
grep -E '^tools:' "$ROOT/agents/reviewer.md" | grep -qE 'Write|Edit' && fail "reviewer 에 Write/Edit 권한" || pass "reviewer read-only"

echo; echo "[4] skills"
for s in vision-intake feature-orchestration; do
  f="skills/$s/SKILL.md"; need "$f"
  grep -qE "^name:[[:space:]]*$s[[:space:]]*$" "$ROOT/$f" 2>/dev/null || fail "$f: name frontmatter"
done

echo; echo "[5] hooks"
need hooks/hooks.json
for ev in SessionStart Stop PreToolUse; do
  jq -e ".hooks.$ev" "$ROOT/hooks/hooks.json" >/dev/null 2>&1 && pass "hooks.json $ev" || fail "hooks.json $ev 미등록"
done
for h in session-context stop-guard protect-files; do
  f="$ROOT/hooks/$h.sh"
  [ -x "$f" ] && pass "$h.sh +x" || fail "$h.sh not executable"
  bash -n "$f" 2>/dev/null || fail "$h.sh 문법 오류"
done

echo; echo "[6] scripts"
for s in setup-harness.sh verify-plugin.sh; do
  f="$ROOT/scripts/$s"
  [ -x "$f" ] && pass "$s +x" || fail "$s not executable"
  bash -n "$f" 2>/dev/null || fail "$s 문법 오류"
done
grep -q 'set -euo pipefail' "$ROOT/scripts/setup-harness.sh" && pass "setup-harness strict mode" || fail "setup-harness: set -euo pipefail"

echo; echo "[7] template"
for f in CLAUDE.md README.md VERSION .gitignore .claude/settings.json .claude/skills/.gitkeep \
         .harness/verify.sh .harness/bin/harness.sh .harness/memory/MEMORY.md \
         .harness/features/.gitkeep .harness/verify.d/.gitkeep; do
  [ -e "$T/$f" ] && pass "$f" || fail "missing: assets/template/$f"
done
[ "$(tr -d '[:space:]' < "$T/VERSION")" = "4" ] && pass "VERSION=4" || fail "VERSION != 4"
for f in .harness/verify.sh .harness/bin/harness.sh; do
  [ -x "$T/$f" ] && pass "$f +x" || fail "$f not executable"
  bash -n "$T/$f" 2>/dev/null || fail "$f 문법 오류"
done
jq -e . "$T/.claude/settings.json" >/dev/null 2>&1 && pass "settings.json valid JSON" || fail "settings.json invalid"
jq -e '.hooks' "$T/.claude/settings.json" >/dev/null 2>&1 && fail "template settings 에 hooks (플러그인 hooks 와 중복)" || pass "template settings: no hooks"
jq -e '.autoMemoryEnabled == true' "$T/.claude/settings.json" >/dev/null 2>&1 && pass "autoMemoryEnabled" || fail "autoMemoryEnabled != true"

echo; echo "[8] CLAUDE.md 게이팅 · 메모리 import"
ct="$T/CLAUDE.md"
grep -qE '^onboarded:[[:space:]]*false' "$ct" && pass "onboarded: false" || fail "onboarded: false 부재"
[ "$(grep -cE '^### [1-8]\.' "$ct")" = "8" ] && pass "비전 8 항목" || fail "비전 항목 수 != 8"
grep -q '^@.harness/memory/MEMORY.md' "$ct" && pass "MEMORY.md import" || fail "MEMORY.md import 부재"

echo; echo "[9] 호칭 — 대표님은 CLAUDE.md/README/vision-intake 에만"
for f in assets/template/CLAUDE.md assets/template/README.md skills/vision-intake/SKILL.md; do
  grep -q "대표님" "$ROOT/$f" && pass "대표님 in $f" || fail "대표님 missing in $f"
done
for f in agents/*.md skills/feature-orchestration/SKILL.md assets/template/.harness/verify.sh \
         assets/template/.harness/bin/harness.sh assets/template/.harness/memory/MEMORY.md; do
  grep -q "대표님" "$ROOT"/$f 2>/dev/null && fail "대표님 leaked into $f" || pass "tool-neutral: $f"
done

echo; echo "[10] 옛 루프 방식 잔재 부재"
for p in commands/goal.md commands/cancel-goal.md commands/expand-plan.md commands/setup-ralph.md \
         hooks/goal-stop-hook.sh scripts/goal-loop.sh scripts/setup-ralph.sh \
         assets/template/PROMPT.md assets/template/AGENTS.md assets/template/IMPLEMENTATION_PLAN.md; do
  [ -e "$ROOT/$p" ] && fail "still present: $p" || pass "absent: $p"
done
if grep -rnE 'goal-loop|PROMPT\.md|IMPLEMENTATION_PLAN|completion-promise|PROJECT_DONE' \
     "$ROOT/commands" "$ROOT/agents" "$ROOT/skills" "$ROOT/hooks" "$T" >/dev/null 2>&1; then
  fail "옛 루프 용어 잔존: $(grep -rlE 'goal-loop|PROMPT\.md|IMPLEMENTATION_PLAN|completion-promise|PROJECT_DONE' "$ROOT/commands" "$ROOT/agents" "$ROOT/skills" "$ROOT/hooks" "$T" | tr '\n' ' ')"
else
  pass "옛 루프 용어 없음"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "[PASS] js-ralph plugin verify ok"
  exit 0
fi
echo "[FAIL] $FAIL check(s) failed"
exit 1
