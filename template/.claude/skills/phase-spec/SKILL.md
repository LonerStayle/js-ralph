---
name: phase-spec
description: chunk 의 cycle 단위 spec 상세화. master-spec 의 chunks/<i>.md acceptance 를 이번 사이클 구체 계획으로 상세화한다. PM (필수) + Designer (UI 있으면). 산출물 state/cycles/<N>/spec.md.
---

# phase-spec

> **source-of-truth = master-spec** (`master-spec.md`). 본 phase 는 master-spec 전체를 재작성하지 않고,
> 현재 사이클에 배정된 `chunks/<i>.md` 의 acceptance criteria 를 구체 실행 계획으로 상세화한다.

## 입력
- `master-spec.md` (전체 목표, 불변 기준)
- `chunks/<i>.md` (이번 사이클에 배정된 chunk — 어떤 acceptance 를 다룰지)

## 절차

1. `chunks/<i>.md` 의 acceptance 항목을 모두 확인한다.
2. pm/* (전체) 가 각 acceptance 항목을 cycle 단위 구체 spec 으로 상세화:
   - 사용자 시나리오 ≥ 1 per acceptance (페르소나 + 트리거 + 흐름 + 기대 결과)
   - 테스트 가능한 acceptance criteria (≥ 5 총계, chunks 원문 그대로 재사용 허용)
   - 비기능 요구 (성능/보안/접근성 — 해당 acceptance 에만 적용)
   - 측정 지표 (movable metric + baseline + 기대 변화, 코드/기능 완성도 기준만)
3. UI 변경 동반 시 designer/* (전체) 가 화면 단위 spec 추가:
   - 와이어 수준 (컴포넌트 + 상태 + 인터랙션)
   - 디자인 토큰/규칙 사용 명시
4. master-spec 항목 중 이번 사이클에서 **의도적으로 제외**한 것은 "defer reason" 적기
   (drop 이 아니라 다음 사이클 예약임을 명시).

## 출력

`state/cycles/<N>/spec.md`:

```
## spec (cycle N) — chunk <i>
### source: chunks/<i>.md
### 상세화된 Acceptance Criteria
- [ ] AC-1 ...
### 사용자 시나리오
1. ...
### 비기능
### 지표 가설
### UI (있으면)
### Deferred (다음 사이클 예약)
- 항목 X: defer reason — ...
```

## gate-verify 통과 조건

- `chunks/<i>.md` 의 모든 acceptance 항목이 spec 에 포함 OR 명시적 defer reason 존재
- AC ≥ 5 (총계)
- 측정 지표 + baseline + 기대 변화 채워짐 (코드/기능 완성도 기준)
- UI 변경이 있으면 와이어 수준 spec 존재

## 다음

`/ralph-spec-done` (또는 `spec-auto-freeze.flag`) → `spec-frozen.flag` 생성 → IMPLEMENT (`/ralph-start` 로 dev/* 직접 구현 진입)
