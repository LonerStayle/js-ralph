---
name: phase-implement
description: 구현 페이즈 프롬프트. 플래너의 plan.md 한 step 을 받아 코드로 옮긴다. /ralph-start 가 이 페이즈로 진입.
---

# phase-implement

## 사전 조건
- `plan.md` 가 존재한다 (planner agent 가 생성).
- `memo/ralph-history.md` 의 직전 entry 를 읽어 컨텍스트 복원.

## 절차

1. plan.md 에서 미완료 step 중 가장 위의 것을 집는다.
2. step 에 적힌 위험/대안을 의식하며 구현.
3. 변경은 한 번에 한 파일 단위로, 작은 diff 우선.
4. 구현 직후 관련 테스트/스모크가 있으면 즉시 실행.
5. 종료 시 plan.md 의 해당 step 에 `- [x]` 마크.

## 다음 페이즈

- 구현 완료 → `verify-loop-output` (자동, Stop hook).
- 막힘/오류 반복 → `phase-debug` 로 라우팅.
