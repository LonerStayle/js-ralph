---
name: verify-loop-output
description: 매 ralph 루프 종료 시 산출물이 요구사항을 충족했는지 자체 채점. Stop hook 에서 자동 호출되거나 /ralph-verify 로 수동 호출.
---

# verify-loop-output

## 입력
- `verify/checklist.md` — 통과 기준 체크리스트
- 이번 루프의 변경 파일 목록 (git diff 또는 메모)
- `memo/ralph-history.md` 의 직전 루프 entry

## 절차

1. checklist.md 의 각 항목을 읽는다.
2. 각 항목에 대해 변경 산출물을 근거로 PASS / FAIL / UNKNOWN 채점.
3. UNKNOWN 은 즉시 추가 검증 명령(테스트 실행/grep/Read)을 자동 수행.
4. 결과 리포트를 `memo/ralph-history.md` 에 append (timestamp + verdict).
5. 하나라도 FAIL 이면 다음 루프 입력에 "이전 실패 항목" 으로 주입할 수 있도록 `memo/last-failures.md` 에 기록.

## 출력 형식

```
## verify <ISO timestamp>
- [PASS] item-1: 근거
- [FAIL] item-2: 이유 + 권고 조치
- [UNKNOWN→PASS] item-3: 추가 확인 결과
verdict: PASS|FAIL
```

## 금지

- 안전 발언("대체로 괜찮음") 금지. 항목별로 명시적 PASS/FAIL.
- 근거 없는 PASS 금지.
