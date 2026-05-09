---
description: SPEC 동결 인가. 사람만 통과시킬 수 있는 게이트. spec-frozen.flag 를 생성해 ralph-tick 가 IMPLEMENT 로 진입할 수 있게 한다.
---

이 커맨드는 **사람의 명시적 인가** 단계다. 자율 ralph-tick 는 이 게이트를 자기 손으로 열 수 없다.

1. `gate-verify(SPEC → IMPLEMENT)` 스킬 호출. 통과해야만 다음 단계.
2. PASS → `state/cycles/<현재 N>/spec-frozen.flag` 파일 생성 (내용: ISO timestamp + "approved by user").
3. `state/ralph-status.md` 의 phase 를 `IMPLEMENT_PENDING_FREEZE` → `IMPLEMENT` 로 갱신.
4. `state/ralph-history.md` 에 `[user-approved] spec-frozen cycle=N` 기록.
5. FAIL → spec 부족 항목 보고, IMPLEMENT_PENDING_FREEZE 유지. 사용자가 spec 보강 후 재호출.

ralph-tick 는 spec.md 를 작성/보강만 할 뿐, 이 flag 를 직접 만들 권한이 없다 (`ralph-tick` 스킬이 명시적으로 차단).
