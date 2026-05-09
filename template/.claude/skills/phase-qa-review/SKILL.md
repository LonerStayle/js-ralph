---
name: phase-qa-review
description: /ralph-done 의 첫 단계. qa/* 페르소나가 spec.md vs 산출물(코드/UI) 을 검수. 이슈는 qa-findings.md 에 기록.
---

# phase-qa-review

## 입력
- `state/cycles/<N>/spec.md` (acceptance criteria)
- 변경된 파일 목록 (git diff 또는 메모)

## 절차

1. qa/* 폴더의 페르소나 중 ≥2 호출 (qa-edge-case 는 항상 포함, 나머지는 변경 종류에 맞춰 — UI 면 qa-ux, 변경 영향 큰 모듈이면 qa-regression).
2. 각 페르소나는 자기 관점에서 issue 보고.
3. spec.md 의 각 AC 에 대해 PASS/FAIL/UNKNOWN 채점도 같이 수행.

## 출력

`state/cycles/<N>/qa-findings.md`:

```
## QA review <ISO ts>
### AC 채점
- [PASS] AC-1 근거
- [FAIL] AC-2 이유
- [UNKNOWN] AC-3 추가 검증 필요 (방법)

### Issues
- 🔴 [qa-edge-case] 빈 입력 시 NPE — file:line — 재현 절차
- 🟡 [qa-ux] CTA 라벨 모호 — ScreenName
- 🟡 [qa-regression] 공유 유틸 변경, 호출자 N개 영향 — file:line
```

## 다음

- 이슈 ≥ 1 또는 AC FAIL ≥ 1 → status=FIXING_QA, dev 에게 fix 요청, 사용자가 fix 후 `/ralph-done` 재호출
- 모두 clean → review-council 자동 진입 (`/ralph-done` 같은 호출 안에서 이어 실행)
