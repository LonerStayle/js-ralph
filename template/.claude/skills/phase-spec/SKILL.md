---
name: phase-spec
description: 사이클 3단계. ideas.md 의 상위 항목을 spec 으로 동결. PM (필수) + Designer (UI 있으면). 산출물 spec.md.
---

# phase-spec

## 입력
- `state/cycles/<N>/ideas.md` (상위 1~3 항목 채택)

## 절차

1. ideas.md 라운드 3 의 ★★★ 항목을 핵심 spec 으로 잡는다. 추가 ★ 항목은 stretch.
2. pm/* (전체) 가 다음을 작성:
   - 사용자 시나리오 ≥ 2 (페르소나 + 트리거 + 흐름 + 기대 결과)
   - acceptance criteria (테스트 가능한 형태, ≥ 5)
   - 비기능 요구 (성능/보안/접근성/i18n 해당 여부)
   - 측정 지표 (movable metric + baseline + 기대 변화)
3. UI 변경 동반 시 designer/* (전체) 가 화면 단위 spec 추가:
   - 와이어 수준 (컴포넌트 + 상태 + 인터랙션)
   - 디자인 토큰/규칙 사용 명시
4. spec 작성 후 모든 라운드 3 항목 중 spec 에서 빠진 것은 명시적으로 "drop reason" 적기 (ideation drop 추적).

## 출력

`state/cycles/<N>/spec.md`:

```
## spec (cycle N)
### 채택
- 항목 1: ...
### Drop (sourced from ideas)
- 항목 X: drop reason — ...
### 사용자 시나리오
1. ...
### Acceptance Criteria
- [ ] AC-1 ...
### 비기능
### 지표 가설
### UI (있으면)
```

## gate-verify 통과 조건

- ideas.md 의 ★★★ 모든 항목이 spec 에 포함 OR 명시적 drop reason 존재
- AC ≥ 5
- 측정 지표 + baseline + 기대 변화 채워짐
- UI 변경이 있으면 와이어 수준 spec 존재

## 다음

`/ralph-spec-done` → IMPLEMENT (`/ralph-start` 로 dev/* 플래너 호출)
