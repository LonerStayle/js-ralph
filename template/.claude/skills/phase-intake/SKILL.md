---
name: phase-intake
description: INTAKE phase. master-spec.md(대표님 동결본)를 cycle 단위 chunk N개로 분해한다. 결과물은 chunks/<i>.md(chunk 상세) + manifest.md(메타 + 카운터). manifest.md 가 이미 있으면 noop(idempotent). 재분해는 /ralph-respec 명시 호출로만 가능.
model: sonnet
---

# phase-intake

> **역할**: 대표님이 동결한 master-spec 을 ralph 가 자율로 실행 가능한 chunk 단위로 분해한다.
> 이 phase 는 사람 review 없이 자동 통과된다. 산출물이 후속 모든 cycle 의 기반이 된다.

## Idempotency 규약

`.claude/state/intake/manifest.md` 의 frontmatter `total_chunks` 값이 **0 보다 크면 이 스킬은 즉시 noop 리턴**한다.
재분해가 필요한 경우 `/ralph-respec` 을 명시적으로 호출해야 한다. ralph-tick 또는 루프의 자동 재실행으로는 재분해되지 않는다.

```
if manifest.md exists AND frontmatter total_chunks > 0:
    log "[phase-intake] manifest already exists (total_chunks={N}). noop — call /ralph-respec to re-chunk."
    exit (no file writes)
```

## 입력

- `.claude/state/intake/master-spec.md` — 대표님 동결본 (frontmatter `frozen: true` 확인)

입력 선결 조건:
- master-spec.md 가 존재하고 `frozen: true` 이어야 한다.
- 존재하지 않거나 미동결이면 INTAKE 진입을 거부하고 onboarding 으로 돌아간다.

## 출력

```
.claude/state/intake/
  chunks/
    1.md          # chunk 1 상세
    2.md          # chunk 2 상세
    ...
    N.md          # chunk N 상세
  manifest.md     # chunk 메타 + 진행 카운터
```

---

## 분해 원칙 (LLM 실행 지침)

아래 4가지 원칙을 모두 지켜야 한다. 하나라도 어기면 분해 결과를 버리고 재수행한다.

### 원칙 1 — 출처 충실 (새 가치 추가 금지)

모든 chunk 는 master-spec **명시 항목**에서만 도출된다.
master-spec 에 없는 기능·요구사항·비기능 항목을 추가하는 것은 금지된다.
"이런 게 있으면 좋을 것 같다"는 판단으로 chunk 를 만들지 않는다.
각 chunk 의 `source_section` 필드에 master-spec 의 어느 섹션/문단에서 왔는지 반드시 인용한다.

### 원칙 2 — 1 chunk = 1 cycle 단위

chunk 1개는 **1 cycle 에 완료 가능한 크기**여야 한다.
acceptance criteria 는 **5~10개** 범위로 설정한다.
- 너무 크면 sub-chunk 로 분리 (예: chunk-3 → chunk-3a, chunk-3b)
- 너무 작으면 인접한 관련 chunk 와 병합

acceptance 개수 기준:
- < 5개: 병합 검토
- 5~10개: 적정
- > 10개: 분리 필수

### 원칙 3 — 의존성 명시

chunk 간 의존 관계가 있으면 `depends_on` 필드에 명시한다.
`depends_on` 이 있는 chunk 는 의존 chunk 가 `ACCEPTED` 상태가 될 때까지 `PENDING` 으로 대기한다.
순환 의존은 허용되지 않는다 — 감지 시 분해를 중단하고 오류를 보고한다.

### 원칙 4 — 출처 인용 필수

각 chunk 의 `source_section` 에 master-spec 의 **섹션 제목 또는 단락 번호**를 명시한다.
"전체 참조" 같은 모호한 인용은 허용되지 않는다. 구체적인 섹션·문단이어야 한다.
master-spec 에 섹션 구분이 없으면 ralph 가 직접 단락 번호를 부여해서 인용한다.

---

## 출력 Schema

### chunks/<i>.md

```markdown
---
chunk_id: <i>               # 정수, 1부터 순차 (sub-chunk: 3a, 3b 허용)
title: "<chunk 한 줄 제목>"
order: <i>                  # 권장 실행 순서 (depends_on 반영)
depends_on: []              # 선행 chunk_id 목록 (없으면 빈 배열)
estimated_cycles: 1         # 예상 소요 사이클 수 (기본 1, 복잡한 chunk 는 2)
status: PENDING             # PENDING | IN_PROGRESS | ACCEPTED | BLOCKED
source_section: "<master-spec 섹션 제목 또는 단락 번호>"
---

## 목표

<이 chunk 가 달성해야 하는 것을 2~4 문장으로>

## 출처 (master-spec 인용)

> 원문: "<master-spec 해당 단락 직접 인용 또는 요약>"
> 위치: <섹션 제목 / 단락 번호>

## Acceptance Criteria

- [ ] AC-1: <테스트 가능한 조건>
- [ ] AC-2: ...
... (총 5~10개)

## 비고

<의존 관계 설명, 특이사항, 분리/병합 사유 등. 없으면 생략>
```

### manifest.md

```markdown
---
total_chunks: <N>
generated_at: "<ISO 8601 timestamp>"
generator: "phase-intake"
master_spec_frozen_at: "<master-spec frontmatter 의 frozen_at 값>"
---

# INTAKE Manifest

## Chunk 목록

| chunk_id | title | order | depends_on | estimated_cycles | status |
|----------|-------|-------|------------|------------------|--------|
| 1        | ...   | 1     | []         | 1                | PENDING |
| 2        | ...   | 2     | [1]        | 1                | PENDING |
| ...      |       |       |            |                  |        |

## 진행 카운터

| 항목 | 값 |
|------|----|
| total | <N> |
| PENDING | <N> |
| IN_PROGRESS | 0 |
| ACCEPTED | 0 |
| BLOCKED | 0 |

## 분해 메모

<분해 과정에서 판단한 사항, 병합/분리 사유, 순환 의존 해소 내역 등>
```

---

## 절차 (단계별)

1. `.claude/state/intake/manifest.md` 존재 여부 확인 → `total_chunks > 0` 이면 **noop 종료**.
2. `master-spec.md` 를 읽고 `frozen: true` 확인. 미동결이면 오류 보고 후 종료.
3. master-spec 을 섹션별로 파싱. 섹션 구분이 없으면 단락 번호 부여.
4. 분해 원칙 1~4 를 적용하여 chunk 목록 초안 작성:
   - 각 항목의 acceptance 개수 확인 (5~10개 범위 조정)
   - 의존 관계 그래프 생성, 순환 의존 검사
   - 실행 순서 (`order`) 위상 정렬
5. 각 `chunks/<i>.md` 파일 작성 (schema 준수).
6. `manifest.md` 작성 (`total_chunks`, `generated_at`, `generator`, 진행 카운터 포함).
7. `state/ralph-history.md` 에 append:
   ```
   [phase-intake] total_chunks=N generated_at=<ISO> master_spec_frozen_at=<ts>
   ```
8. `state/ralph-status.md` 의 phase 를 `CHUNK_DETAIL` 로 갱신 (다음 chunk_id=1).

## gate-verify 통과 조건

- `manifest.md` 가 존재하고 `total_chunks >= 1`
- 모든 chunk 파일 (`chunks/1.md` ~ `chunks/N.md`) 이 존재
- 각 chunk 에 `source_section` 이 모호하지 않게 채워짐
- 각 chunk 의 acceptance criteria 가 5~10개 범위
- 순환 의존 없음

> INTAKE 는 gate-verify PASS 후 사람 review 없이 자동으로 CHUNK_DETAIL (chunk 1) 으로 진입한다.
