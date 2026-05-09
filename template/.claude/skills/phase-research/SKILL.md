---
name: phase-research
description: 사이클 1단계. 시장/사용자/경쟁사/기존 데이터를 조사. 산출물 research.md. /ralph-research-done 으로 종료.
---

# phase-research

## 입력
- 직전 사이클의 `cycles/<N-1>/done.md` (있으면)
- 현 사이클 번호 = `state/current-cycle`

## 절차

1. 조사 차원 5개를 결정 (예: 사용자 페르소나 변화, 경쟁 제품 신기능, 내부 텔레메트리 추세, 미해결 사용자 요청 큐, 시장 트렌드).
2. 각 차원에 대해 marketer/* + pm/metrics-driven 페르소나 호출 (각 ≥1).
3. 각 페르소나가 1~2 finding 을 근거(URL/지표/티켓 ID)와 함께 보고.
4. 종합하여 `state/cycles/<N>/research.md` 작성.
   - 형식: 차원별 섹션 + finding 리스트 + 출처
   - "근거 없는" 주장 금지 — 그런 항목은 "TODO 검증" 으로 표기

## 출력 검증

`gate-verify` 가 다음을 확인:
- finding ≥ 5개
- 각 finding 에 출처 명시
- 직전 사이클의 미해결 항목 (cycles/<N-1>/gaps.md) 이 검토되었는가

## 다음

`/ralph-research-done` → IDEATION
