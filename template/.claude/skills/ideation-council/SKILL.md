---
name: ideation-council
description: 사이클 2단계. 발산형 회의. 전 역할 ≥1 페르소나가 research.md 를 입력으로 다양한 아이디어를 낸다. 산출물 ideas.md (랭크).
---

# ideation-council

## 입력
- `state/cycles/<N>/research.md`

## 절차 (라운드 3회)

**라운드 1 — 발산 (각 페르소나 독립 발언, 서로 미참조)**
- 모든 역할 폴더에서 ≥1 페르소나 호출 (pm/dev/qa/designer/marketer)
- 각 페르소나는 research finding 중 가장 강하게 반응하는 1~2개에 대해 아이디어 ≥3개 제시
- 발언 길이 ≤ 5줄

**라운드 2 — 충돌 (이의 + 합치)**
- 라운드 1 발언을 다 본 뒤, 각 페르소나가 "내 역할 관점에서 위험하거나 잘못된" 아이디어를 명시적으로 거부
- 거부 사유는 1줄

**라운드 3 — 우선순위**
- pm/strategic + pm/metrics-driven 두 페르소나가 살아남은 아이디어를 다음 기준으로 랭크:
  - 임팩트 (지표 이동 기대)
  - 리스크
  - 사이클 1회 분량 적합성

## 출력

`state/cycles/<N>/ideas.md`:

```
## ideas (cycle N)
### 라운드 1 (발산)
- [pm-strategic] ...
- [dev-architect] ...
...

### 라운드 2 (탈락)
- [reject by qa-edge-case] ... 사유
...

### 라운드 3 (rank)
1. ★★★ ...
2. ★★ ...
3. ★ ...
```

## gate-verify 통과 조건

- 모든 5역할 중 ≥4역할이 라운드 1에 발언했는가 (해당 하네스에서 활성된 역할만)
- 라운드 2에서 ≥1 거부가 있었는가 (전부 합의면 의심 — diverse perspective 실패)
- 라운드 3 ≥3개 항목

## 다음

`/ralph-ideation-done` → SPEC
