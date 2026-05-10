---
name: chunk-detail
description: CHUNK_DETAIL phase. v1 의 RESEARCH+IDEATION 을 단일 phase 로 통합. master-spec 이 source-of-truth 이므로 새 가치 발굴은 금지. 이번 사이클 chunk 의 구현 방안 후보 + 디테일만 채운다.
model: sonnet
---

# chunk-detail

> **v1 → v2 통합**: v1 의 `RESEARCH` (시장조사) + `IDEATION` (발산형 회의) 두 phase 를
> **단일 `CHUNK_DETAIL` phase** 로 통합. v2 모델에서 master-spec 이 대표님이 작성한 외부
> source-of-truth 이므로, 새로운 가치·기능·아이디어 발굴은 이 phase 의 역할이 아니다.
> 본 skill 은 "master-spec 의 chunk 안 디테일을 어떻게 구현할 것인가" 만 다룬다.

---

## 원칙 (3가지 — 위반 시 gate-verify FAIL)

1. **master-spec chunk 외 항목 추가 금지 (drift 방지)**
   - `chunks/<i>.md` 의 acceptance criteria 범위 밖 기능·요구사항을 새로 도입하지 않는다.
   - "있으면 좋을 것 같은" 아이디어, 확장 제안, 새 가치 추가 금지.
   - chunk 에 없는 항목은 chunk-detail.md 에 등장하면 안 된다.

2. **구현 방안 후보 2-3개 + 권장 + 트레이드오프**
   - 각 acceptance 항목에 대해 구현 방안 후보를 2-3개 제시한다.
   - 각 후보마다 트레이드오프 (장/단, 비용, 복잡도) 를 명시한다.
   - 권장 방안을 1개 선택하고 선택 이유를 간략히 쓴다.

3. **acceptance 충족 디테일 (HOW)**
   - `chunks/<i>.md` 의 각 acceptance criteria 가 "어떻게 충족되는가 (HOW)" 를 구체적으로 기술한다.
   - 테스트 가능한 수준의 구체성 필요: API 엔드포인트, 데이터 모델, 핵심 알고리즘, UI 흐름 등.
   - 추상적 "구현 예정" 수준의 기술은 FAIL 처리된다.

---

## 입력

- `.claude/state/intake/chunks/<i>.md` — 이번 사이클에 배정된 chunk (acceptance criteria 포함)
- `.claude/state/intake/master-spec.md` — 전체 목표, source-of-truth (참조만, 새 항목 추가 불가)

## 절차

1. `state/ralph-status.md` 에서 현재 `cycle=N`, `chunk=<i>` 를 확인한다.
2. `intake/chunks/<i>.md` 를 읽어 acceptance criteria 목록을 추출한다.
3. `intake/master-spec.md` 를 읽어 이번 chunk 의 출처 문단을 확인한다 (컨텍스트 파악용).
4. 각 acceptance criterion 에 대해 구현 방안 후보를 2-3개 생성한다:
   - 후보별 트레이드오프 (복잡도 / 비용 / 유지보수성 / 성능) 기술
   - 권장 방안 1개 선택 + 선택 이유
   - HOW 디테일: 코드 구조, 파일/모듈 단위, 핵심 API, 데이터 모델, UI 흐름 등
5. drift 자가점검: 생성한 항목이 모두 `chunks/<i>.md` 의 acceptance 안에 있는지 확인. 벗어난 항목 있으면 즉시 제거.
6. `state/cycles/<N>/chunk-detail.md` 를 작성한다.

## 출력

`state/cycles/<N>/chunk-detail.md`:

```
## chunk-detail (cycle N) — chunk <i>
### source: intake/chunks/<i>.md

### AC-CHUNK-<i>-1: <acceptance criterion 원문>

#### 구현 방안 후보

| # | 방안 | 트레이드오프 |
|---|------|------------|
| A | ...  | 장: ... / 단: ... |
| B | ...  | 장: ... / 단: ... |
| C | ...  | 장: ... / 단: ... |

**권장**: 방안 A — <이유 1-2문장>

#### HOW (권장 방안 기준 구현 디테일)

- 파일/모듈: ...
- API / 데이터 모델: ...
- 핵심 로직: ...
- 테스트 가능 경계: ...

---

### AC-CHUNK-<i>-2: ...

(동일 패턴 반복)
```

---

## drift detection (gate-verify 가 호출 시)

gate-verify 가 `CHUNK_DETAIL → SPEC` 게이트에서 다음을 점검한다:

- `chunk-detail.md` 에 등장하는 기능·요구사항 항목이 **모두** `chunks/<i>.md` 의 acceptance criteria 안에 있는가.
- `chunks/<i>.md` 에 없는 새 항목이 1개라도 존재하면 → **FAIL** → IMPLEMENT 직회귀 (CHUNK_DETAIL 재진입).
- `chunks/<i>.md` 의 acceptance criterion 이 `chunk-detail.md` 에 누락된 경우도 FAIL (누락 = HOW 미작성).

**FAIL 시 기록 위치**: `state/cycles/<N>/chunk-detail-deficit.md` 에 위반 항목 기록.

---

## gate-verify 통과 조건

- `chunk-detail.md` 가 존재하고 비어 있지 않다 (TODO 만인 파일 거부).
- `chunks/<i>.md` 의 **모든** acceptance criterion 이 chunk-detail.md 에 각각 등장한다.
- 각 criterion 에 구현 방안 후보 ≥ 2, 권장 방안 1개, HOW 디테일이 모두 기술되어 있다.
- drift 항목 (master-spec chunk 외 추가) 이 0개이다.

---

## 다음

gate-verify PASS → `phase-spec` (chunk acceptance criteria 의 구체 실행 계획 상세화)
