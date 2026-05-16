#!/usr/bin/env bash
# v3-classic template 정적 검증
#
# 합격 기준 (Geoffrey 오리지널 + 대표님 호칭):
#   존재:
#     template/PROMPT.md
#     template/AGENTS.md
#     template/IMPLEMENTATION_PLAN.md
#     template/specs/                          (디렉토리)
#     template/CLAUDE.md
#     template/README.md
#     template/VERSION                         (내용 == 3)
#     template/.claude/settings.json
#     template/.claude/skills/onboarding/SKILL.md
#   부재 (v2 잔재 폐기 확인):
#     template/.claude/agents/
#     template/.claude/commands/
#     template/.claude/state/
#     template/.claude/hooks/
#     template/.claude/config/
#     template/.claude/scripts/
#     template/HANDOFF.md
#   skills/ 안에 onboarding 하나만 존재
#   PROMPT.md / CLAUDE.md 에 "대표님" 키워드 박힘
#   settings.json 에 hooks 섹션 없음

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$ROOT/template"
FAIL=0

pass() { echo "  [ok] $*"; }
fail() { echo "  [FAIL] $*" >&2; FAIL=$((FAIL+1)); }

echo "=== v3-classic template verify ==="
echo "root: $T"

# 1. 존재해야 하는 것
echo
echo "[1] required files / dirs"
for path in \
  "PROMPT.md" "AGENTS.md" "IMPLEMENTATION_PLAN.md" \
  "CLAUDE.md" "README.md" "VERSION" \
  ".claude/settings.json" \
  ".claude/skills/onboarding/SKILL.md"
do
  if [ -e "$T/$path" ]; then pass "$path"; else fail "missing: $path"; fi
done

if [ -d "$T/specs" ]; then pass "specs/ (dir)"; else fail "missing dir: specs/"; fi

# 2. 부재해야 하는 것 (v2 잔재)
echo
echo "[2] v2 vestiges must be absent"
for path in \
  ".claude/agents" ".claude/commands" ".claude/state" ".claude/hooks" \
  ".claude/config" ".claude/scripts" "HANDOFF.md"
do
  if [ -e "$T/$path" ]; then fail "still present: $path"; else pass "absent: $path"; fi
done

# 3. skills/ 안엔 onboarding 만
echo
echo "[3] skills/ contains only onboarding"
if [ -d "$T/.claude/skills" ]; then
  skill_entries=$(ls -1 "$T/.claude/skills" 2>/dev/null | sort | tr '\n' ' ')
  if [ "$(echo "$skill_entries" | tr -d ' ')" = "onboarding" ]; then
    pass "skills entries = onboarding"
  else
    fail "skills/ has unexpected entries: $skill_entries"
  fi
else
  fail "skills/ dir missing"
fi

# 4. VERSION == 3
echo
echo "[4] VERSION"
v="$(tr -d '[:space:]' < "$T/VERSION" 2>/dev/null || echo)"
if [ "$v" = "3" ]; then pass "VERSION = 3"; else fail "VERSION = '$v' (expected 3)"; fi

# 5. 대표님 호칭 분리 검증
#    - PROMPT.md / AGENTS.md / IMPLEMENTATION_PLAN.md 는 도구 중립이어야 함 (대표님 부재)
#    - CLAUDE.md / README.md / onboarding SKILL 에는 박혀 있어야 함
echo
echo "[5] 대표님 호칭 분리 (CLAUDE 본거지, PROMPT 도구 중립)"
for f in "PROMPT.md" "AGENTS.md" "IMPLEMENTATION_PLAN.md"; do
  if grep -q "대표님" "$T/$f" 2>/dev/null; then
    fail "대표님 leaked into $f (must be tool-neutral)"
  else
    pass "tool-neutral: $f"
  fi
done
for f in "CLAUDE.md" "README.md" ".claude/skills/onboarding/SKILL.md"; do
  if grep -q "대표님" "$T/$f" 2>/dev/null; then
    pass "대표님 in $f"
  else
    fail "대표님 missing in $f"
  fi
done

# 6. settings.json — hooks 없음
echo
echo "[6] settings.json has no hooks section"
if grep -q '"hooks"' "$T/.claude/settings.json"; then
  fail "settings.json still has hooks section"
else
  pass "no hooks in settings.json"
fi

# 7. PROMPT.md / CLAUDE.md — Geoffrey 정석 키워드
echo
echo "[7] Geoffrey 정석 anchor"
if grep -qE "(fresh context|ralph-loop|specs/)" "$T/PROMPT.md"; then
  pass "PROMPT.md references fresh context / ralph-loop / specs/"
else
  fail "PROMPT.md missing Geoffrey anchors"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "[PASS] v3-classic template ok"
  exit 0
else
  echo "[FAIL] $FAIL check(s) failed"
  exit 1
fi
