# 모델 라우팅 (원칙 5)

각 agent / 스킬이 어떤 모델을 왜 쓰는지 결정 근거.

## Agents

| Agent | 모델 | 이유 |
|-------|------|------|
| pm/pm-strategic | opus | 장기 ROI / 경쟁 우위, 추론 깊이 |
| pm/pm-user-empathic | sonnet | 시나리오 추론 |
| pm/pm-metrics-driven | sonnet | 지표 정의/매핑 |
| dev/dev-architect | opus | 아키텍처 + 플래너, 깊이 필요 |
| dev/dev-pragmatist | sonnet | 빠른 MVP 플래닝 |
| dev/dev-security-paranoid | sonnet | 패턴 인식 위주 |
| qa/* | sonnet | 변경 영역 추적 + 케이스 발산 |
| designer/* | sonnet | 시각/UX 패턴 |
| marketer/* | sonnet | 카피/그로스 |

## 스킬 (메인 에이전트가 수행)

| 스킬 | 모델 | 이유 |
|------|------|------|
| phase-research | sonnet | 정리/요약 |
| ideation-council | sonnet | 다중 페르소나 호출 비용 가드 (역할당 ≥1) |
| phase-spec | sonnet | 구조화된 작성 |
| phase-implement | sonnet | 코드 작성 기본 |
| phase-qa-review | sonnet | qa/* agent 호출 + 종합 |
| review-council | sonnet | 비용 가드 |
| gap-analysis | opus | spec ↔ 산출물 정밀 대조, 깊이 필요 |
| gate-verify | sonnet | 점검 체크리스트 |
| verify-loop-output | sonnet | 체크리스트 채점 |
| phase-debug | opus | 근본 원인 추적 |

## 규칙

- 새 agent / 스킬 추가 시 반드시 이 표에 한 줄 추가하고 근거 명시.
- "더 좋아 보여서 opus" 같은 근거는 거부. 측정 가능한 이유만.
- council 류는 페르소나 N명 동시 호출이라 항상 sonnet 이하 (opus 강제 페르소나는 pm-strategic, dev-architect 만).
