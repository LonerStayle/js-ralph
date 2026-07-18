---
description: "활성 goal 루프를 취소합니다."
allowed-tools: ["Bash(test -f .claude/goal-loop.local.md:*)", "Bash(rm .claude/goal-loop.local.md)", "Read(.claude/goal-loop.local.md)"]
hide-from-slash-command-tool: "true"
---

# Cancel Goal

goal 루프를 취소하려면:

1. `.claude/goal-loop.local.md` 존재 확인 (Bash): `test -f .claude/goal-loop.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **NOT_FOUND 이면**: "활성 goal 루프가 없습니다." 라고 알립니다.

3. **EXISTS 이면**:
   - `.claude/goal-loop.local.md` 를 Read 해서 `iteration:` 값(현재 iteration 번호)을 확인
   - Bash 로 파일 제거: `rm .claude/goal-loop.local.md`
   - 보고: "goal 루프를 취소했습니다 (iteration N 에서 중단)" — N 은 읽어온 iteration 값
