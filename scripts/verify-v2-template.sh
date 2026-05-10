#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/template"
fail() { echo "FAIL: $1" >&2; exit 1; }

# AC-5: phase 정의 표 갱신
grep -q "INTAKE" "$TEMPLATE/.claude/state/ralph-status.md" || fail "ralph-status 에 INTAKE 부재"
grep -q "CHUNK_DETAIL" "$TEMPLATE/.claude/state/ralph-status.md" || fail "ralph-status 에 CHUNK_DETAIL 부재"

# AC-1: 신규 스킬 존재
for s in onboarding phase-intake chunk-detail notify-sender; do
  test -d "$TEMPLATE/.claude/skills/$s" || fail "$s skill 부재"
done

# AC-1: 폐기 스킬 부재
for s in phase-research ideation-council; do
  test ! -e "$TEMPLATE/.claude/skills/$s" || fail "$s skill 미삭제"
done

# AC-1: state/intake placeholder
test -f "$TEMPLATE/.claude/state/intake/master-spec.md" || fail "master-spec.md 부재"
test -f "$TEMPLATE/.claude/state/intake/manifest.md" || fail "manifest.md 부재"

# AC-1: notify config
test -f "$TEMPLATE/.claude/config/notify.md" || fail "notify.md 부재"

# AC-1: 페르소나 대표님 키워드
for f in "$TEMPLATE"/.claude/agents/{pm,dev,qa,designer,marketer}/*.md; do
  grep -q "대표님" "$f" || fail "$f 에 '대표님' 부재"
done

# AC-1: 6원칙 (7원칙 부재) — 매핑 표 헤더 검사
! grep -E "^\| 7\." "$ROOT/CLAUDE.md" 2>/dev/null || fail "루트 CLAUDE.md 에 7원칙 잔존"
! grep -E "^\| 7\." "$TEMPLATE/CLAUDE.md" 2>/dev/null || fail "template CLAUDE.md 에 7원칙 잔존"

# AC-1: 폐기 슬래시 커맨드 부재
for c in ralph-research-done ralph-ideation-done ralph-spec-done ralph-cycle-start; do
  test ! -e "$TEMPLATE/.claude/commands/$c.md" || fail "$c.md 미삭제"
done

echo "verify-v2-template: ALL PASS"
