---
total_chunks: 0
generated_at: null
generator: pending
---

# chunk manifest

CHUNK_DETAIL phase 에서 생성되는 구현 단위(chunk) 목록.
각 chunk 는 `intake/chunks/<id>.md` 파일로 저장되며, 이 파일이 그 진행 상태를 추적한다.

---

## 진행 표 (Progress Table)

| id | 제목 | 상태 | 담당 phase | 완료 시각 |
|----|------|------|------------|-----------|
| (CHUNK_DETAIL 완료 후 자동 채워짐) | | | | |

---

## 상태 정의 (Status Definitions)

| 상태 값 | 의미 |
|---------|------|
| `PENDING` | 아직 구현 시작 전 |
| `IN_PROGRESS` | 현재 IMPLEMENT phase 에서 작업 중 |
| `QA` | QA_REVIEW 진행 중 |
| `BLOCKED` | 외부 의존 또는 선행 chunk 미완료로 대기 |
| `DONE` | 모든 게이트 통과, 해당 chunk 완료 |

---

## Counters 설명

- `total_chunks`: CHUNK_DETAIL 완료 시 확정되는 전체 chunk 수. 0 이면 아직 미생성.
- `generated_at`: manifest 첫 생성 시각 (ISO 8601). CHUNK_DETAIL 스킬이 기록.
- `generator`: manifest 를 생성한 에이전트/스킬 이름. CHUNK_DETAIL 완료 후 기록.

---

## BLOCKED 사유 로그

chunk 가 BLOCKED 상태가 될 때마다 아래에 append. 해소 시 해소 시각과 사유도 기록.

| 시각 | chunk id | BLOCKED 사유 | 해소 시각 | 해소 방법 |
|------|----------|-------------|-----------|-----------|
| (없음) | | | | |
