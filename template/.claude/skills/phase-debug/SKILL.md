---
name: phase-debug
description: 디버그 페이즈 프롬프트. 동일 오류가 2회 이상 반복되거나 verify FAIL 시 진입.
---

# phase-debug

## 진입 조건
- 같은 오류 메시지/스택이 2회 이상 등장
- verify-loop-output 이 FAIL 반환
- 사용자가 명시적으로 디버그 모드 요청

## 절차

1. 오류 메시지 원문을 그대로 인용한다 (요약 금지).
2. 가설 ≥ 3개 나열. 각 가설에 검증 방법 명시.
3. 가장 빠른 가설부터 검증 (Read/grep/Bash).
4. 근본 원인 (root cause) 을 한 문장으로 적기 전에는 fix 시도 금지.
5. 수정 후 같은 입력으로 재현 시도하여 회귀 여부 확인.
6. `memo/ralph-history.md` 에 [debug] entry 로 root cause + fix 기록.

## 금지

- 증상 회피 (try/except 로 감싸기, 로그 끄기, 검증 비활성화)
- "아마 이게 원인일 듯" 식 추측 기반 수정
