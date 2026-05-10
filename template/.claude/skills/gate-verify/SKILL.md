---
name: gate-verify
description: 모든 페이즈 전이 직전에 호출되는 공통 게이트 검증. 직전 페이즈 산출물의 적합성을 점검하고, 통과해야 다음 페이즈로 넘어간다.
---

# gate-verify

## 입력
- `from_phase`: 직전 페이즈
- `to_phase`: 진입 시도 페이즈
- 현 사이클 폴더: `.claude/state/cycles/<N>/`
- `.claude/state/intake/chunks/<i>.md` (CHUNK_DETAIL → SPEC 전이 시)

## 점검 항목 (기본 3가지 + 페이즈별 추가 검증)

1. **산출물 존재 + 비공허**
   - from_phase 의 표준 산출물 파일이 존재하는가
   - 길이/항목 수가 최소치 이상인가 (TODO 만 있는 빈 파일 거부)

2. **drop 추적 (이전 합의 항목 사라졌는지)**
   - from_phase 가 이전 페이즈의 합의 항목들을 명시적 근거 없이 제거했는지 점검
   - master-spec chunk 의 acceptance 항목이 산출물에 반영됐는지 확인
   - 예: chunk 의 acceptance criteria 가 spec.md 에 없으면 그 이유가 적혀 있어야 함 (drop 사유)

3. **다음 페이즈 입력 충족**
   - to_phase 가 필요로 하는 입력이 from_phase 산출물 안에 갖춰졌는가
   - 예: SPEC → IMPLEMENT 진입 시, spec.md 에 acceptance criteria 가 있어야 함

## 페이즈별 추가 검증

### CHECKLIST phase 진입 시 (from_phase = CHECKLIST, to_phase = CYCLE_DONE)
- `cycles/<N>/runtime-evidence.md` 파일이 존재하는가
- `runtime-evidence.md` 에 **"자동 검증"** 섹션이 채워져 있는가 (빈 섹션 거부)
- `runtime-evidence.md` 에 **"캡처"** 섹션이 채워져 있는가 (빈 섹션 거부)
- 위 조건 중 하나라도 미충족 → `runtime-evidence-missing: FAIL` → CHECKLIST FAIL → IMPLEMENT 직회귀

### CHUNK_DETAIL → SPEC 전이 시 (drift 검증)
- 현 cycle 의 산출물 항목들 ⊆ `chunks/<i>.md` 의 acceptance criteria 검증
- chunk 에 없는 항목이 spec 에 추가됐다면 → drift 가능성. 추가 사유가 spec 에 명시돼 있어야 함
- chunk 의 acceptance 항목이 산출물에서 누락됐다면 → drop 사유 없으면 FAIL
- `drift-check: PASS|FAIL (drift 항목 목록 + 사유)` 로 기록

## 출력

`.claude/state/cycles/<N>/gate-verifies.md` 에 entry append:

```
## <ISO timestamp> [<from_phase> → <to_phase>]
- artifact-non-empty: PASS|FAIL (근거)
- drop-tracking: PASS|FAIL (drop 항목 + 사유 검증)
- next-input-ready: PASS|FAIL (요구 입력 vs 실제)
- runtime-evidence: PASS|FAIL|N/A (CHECKLIST 전이 시만)
- drift-check: PASS|FAIL|N/A (CHUNK_DETAIL→SPEC 시만)
verdict: PASS|FAIL
```

## 실패 처리

하나라도 FAIL → 다음 페이즈 진입 거부.
- ralph-status.md 의 phase 는 from_phase 그대로 유지
- 사용자에게 어떤 항목이 FAIL 인지 보고
- CHECKLIST runtime-evidence FAIL 시 → phase=IMPLEMENT 직회귀 (CHECKLIST 재시도 불가)
- 사용자가 from_phase 산출물 보강 → 다시 호출
