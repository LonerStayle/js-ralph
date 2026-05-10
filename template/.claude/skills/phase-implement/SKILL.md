---
name: phase-implement
description: 구현 페이즈 프롬프트. dev/* 페르소나가 현재 chunk 의 cycle spec 을 직접 구현한다. /ralph-start 가 이 페이즈로 진입.
---

# phase-implement

## 사전 조건
- `state/cycles/<N>/spec.md` 가 존재하고 `spec-frozen.flag` 가 세팅되어 있다.
- `state/ralph-history.md` 의 직전 entry 를 읽어 컨텍스트 복원.

## 절차

1. `state/cycles/<N>/spec.md` 에서 구현 대상 acceptance criteria 를 확인한다.
2. dev/* 페르소나(architect → pragmatist → security-paranoid 순) 가 직접 구현한다.
   - architect: 변경 범위·의존성 파악, 파일 단위 작업 목록 결정.
   - pragmatist: 실제 코드 작성. 변경은 한 번에 한 파일 단위, 작은 diff 우선.
   - security-paranoid: 새 입력 경로·인증·의존성 위험 즉시 지적 후 수정.
3. 구현 직후 관련 테스트/스모크가 있으면 즉시 실행.
4. AC 항목마다 완료 여부를 `spec.md` 에 `- [x]` 로 마크.

## 다음 페이즈

- 구현 완료 → `verify-loop-output` (자동, Stop hook).
- 막힘/오류 반복 → `phase-debug` 로 라우팅.
