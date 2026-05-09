---
description: 새 사이클 시작. cycle 카운터 증가, RESEARCH 페이즈 진입.
---

새 사이클을 시작한다.

1. `state/current-cycle` 의 숫자를 +1 (없으면 1로 초기화).
2. `state/cycles/<N>/` 폴더 생성.
3. `state/ralph-status.md` 갱신: `cycle=N, phase=RESEARCH`.
4. `phase-research` 스킬 진입.
5. 직전 사이클이 있으면 `state/cycles/<N-1>/done.md` 와 `gaps.md` 의 TRACKING 항목을 RESEARCH 입력으로 인용.

`gate-verify(NOT_STARTED → RESEARCH)` 는 첫 사이클에선 스킵.
