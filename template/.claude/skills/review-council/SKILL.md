---
name: review-council
description: /ralph-done 의 둘째 단계. QA-clean 후 진입. 활성 역할이 spec 충족 여부 + 비기능/브랜드/시장 관점 우려를 수렴형으로 검토.
---

# review-council

## 활성 역할 결정 규칙

매 호출 시 변경 내용을 보고 활성 역할 결정:
- pm/* — 항상 활성 (필수)
- dev/* — 항상 활성 (필수, 구현 일관성 검토)
- qa/* — 이전 단계에서 이미 봄, 여기선 dev 의 fix 가 새 회귀 만들었는지 1명만 (qa-regression)
- designer/* — UI/스타일/CSS/JSX 변경이 있으면 활성
- marketer/* — 카피/랜딩/메일/공유 텍스트/요금 변경이 있으면 활성

활성 역할당 ≥1 페르소나 발화 (비용 가드).

## 절차 (라운드 2회)

**라운드 1 — 발화**
- 각 활성 페르소나가 ≤ 5줄로 우려 또는 PASS 의견.
- spec.md 의 각 채택 항목이 산출물에서 보이는지 확인.
- 우려 발견 시 구체 파일/문구 인용.

**라운드 2 — 합의**
- pm/strategic 이 라운드 1 의견을 종합:
  - 우려 항목 ≥ 1 + 최소 1명이 "REVISE" 입장 → council 결과 = REVISE
  - 모든 페르소나 PASS → council 결과 = PASS

## 출력

`state/cycles/<N>/council-feedback.md`:

```
## review-council <ISO ts>
### 활성 역할: pm, dev, [designer], [marketer]
### 라운드 1
- [pm-strategic] ...
- [dev-architect] ...
- [designer-pixel-perfect] ...

### 합의
verdict: PASS | REVISE
- (REVISE 면) 우선 처리 항목 1~3개
```

## 다음

- REVISE → status=FIXING_COUNCIL, fix 후 `/ralph-done` 재호출
- PASS → gap-analysis 자동 진입
