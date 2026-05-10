---
name: gap-analysis
description: /ralph-done 의 셋째 단계. council PASS 후 진입. master-spec chunks/<i>.md vs 실제 산출물을 PM 이 1:1 대조해 누락분 추출.
---

# gap-analysis

## 입력
- `.claude/state/intake/chunks/<i>.md` (현 cycle 의 master-spec chunk — source-of-truth)
- `state/cycles/<N>/qa-findings.md`, `council-feedback.md` (참고용)
- 코드/산출물 현재 상태

> **비교 기준 변경 (v2)**: 기존 `cycles/<N>/spec.md` (ralph 가 cycle 별로 만든 spec) 대신
> **master-spec chunks/<i>.md** 를 source-of-truth 로 사용한다.
> cycles/<N>/spec.md 는 참고용 보조 문서로만 취급.

## 절차

1. pm/* 전체 호출 (3 페르소나).
2. 각 페르소나가 **`chunks/<i>.md`** 의 다음을 1:1 대조:
   - 채택 항목 (모두 산출물에 반영?)
   - acceptance criteria (모두 PASS?)
   - 사용자 시나리오 (chunk 에 기술된 시나리오 가능?)
   - 비기능 요구 (성능/보안/접근성/i18n — chunk 에 명시된 것)
   - 측정 지표 (chunk 에 명시된 이벤트/로그 추가됨?)
3. 누락 항목 = gap.

## 누락 분류

- **CRITICAL gap** — chunk 의 핵심 acceptance criteria 가 산출물에 없음 → 반드시 IMPLEMENT 재진입
- **DEFERRED gap** — 채택은 됐지만 stretch / 명시적 drop. drop reason 검증 후 OK
- **TRACKING gap** — 다음 chunk/사이클에서 다룰 항목 (예: 측정 지표가 즉시 작동하지 않아도 다음 사이클에서 합류)

## 출력

`state/cycles/<N>/gaps.md`:

```
## gap-analysis <ISO ts>
### 비교 기준: chunks/<i>.md (master-spec chunk)
### CRITICAL (이번 사이클 내 처리 필수)
- [ ] AC-3 미구현 — file 위치 추정
- [ ] 보안 요구 X 미반영

### DEFERRED (drop 검증 완료)
- 항목 Y — drop reason: ...

### TRACKING (다음 chunk/사이클로)
- 측정 이벤트 dashboard 연동 — ETA chunk N+1
```

## 다음

- CRITICAL ≥ 1 → status=FIXING_GAP, IMPLEMENT 재진입, fix 후 `/ralph-done` 재호출
- 모두 OK → CHECKLIST (verify-loop-output) 자동 진입
