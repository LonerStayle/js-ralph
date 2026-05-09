---
description: 구현 페이즈 시작. spec.md 동결 후 dev/* 플래너 호출 → phase-implement 진입.
---

전제:
- `ralph-status.md` 의 phase 가 `IMPLEMENT` 인 상태여야 한다 (즉 `/ralph-spec-done` 통과 후).
- 그렇지 않으면 현 phase 를 사용자에게 알리고 적절한 진입 커맨드 안내.

절차:
1. `bootstrap` 통과 흔적 확인 (`ralph-history.md` 에 `[deploy] PASS`). 없으면 `/ralph-deploy` 먼저 안내.
2. `state/cycles/<N>/plan.md` 가 없거나 모든 step `[x]` 면, dev/* 플래너 호출:
   - 기본: `dev-architect`
   - MVP 우선: `dev-pragmatist` (사용자가 명시 시)
3. plan 의 첫 미완료 step 을 잡고 `phase-implement` 스킬 진입.
4. 매 step 후 PostToolUse hook 이 history append.
5. 모든 step 완료 → 사용자에게 `/ralph-done` 호출 안내.
