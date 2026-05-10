# ralph status

cycle: 0
phase: NOT_STARTED
last_gate_verify: none
last_qa: none
last_council: none
last_intake: none
last_dispatch: none
last_telegram: none
fail_streak: 0

---

## phase 값 정의 (ralph-tick 가 이 순서로 자동 전진)

```
NOT_STARTED
   → INTAKE                    ← 사용자 프로젝트 의도 수집 + master-spec.md 초안
   → CHUNK_DETAIL              ← INTAKE 산출물을 구현 chunk 단위로 분할 + manifest.md 생성
   → SPEC                      ← chunk 별 기획/디자인 동결 (spec-frozen.flag 필요)
   → IMPLEMENT                 ← chunk 단위 구현 (내부 루프)
   → QA_REVIEW       (내부 루프: 이슈 → IMPLEMENT)
   → REVIEW_COUNCIL  (내부 루프: 우려 → IMPLEMENT)
   → GAP_ANALYSIS    (내부 루프: gaps → IMPLEMENT)
   → CHECKLIST       (내부 루프: FAIL → IMPLEMENT)
   → CYCLE_DONE
   → (project-stop-check) → PROJECT_DONE  또는  NOT_STARTED (다음 사이클)
```

**STUCK_<phase>** — 같은 phase 에서 gate-verify FAIL 5회 연속 시 자동 진입. 다음 tick 부터 noop. 사람이 deficit.md 보고 개입 후 fail_streak 리셋.

**PROJECT_DONE** — project-stop-check STOP 또는 `/ralph-stop` 명시 호출 시. ralph-loop 도 종료 권고.

게이트 우회는 이 파일 직접 편집으로만 가능. 그 사실은 `ralph-history.md` 에 기록될 것.

---

## 메타 헤더 필드 설명

| 필드 | 설명 |
|------|------|
| `cycle` | 현재 사이클 번호 (0 = 미시작) |
| `phase` | 현재 phase 값 (위 정의 참조) |
| `last_gate_verify` | 마지막 gate-verify 통과 시각 (ISO 8601 또는 "none") |
| `last_qa` | 마지막 QA_REVIEW 완료 시각 |
| `last_council` | 마지막 REVIEW_COUNCIL 완료 시각 |
| `last_intake` | 마지막 INTAKE 완료 시각 |
| `last_dispatch` | 마지막 CHUNK_DETAIL dispatch 완료 시각 |
| `last_telegram` | 마지막 Telegram 알림 전송 시각 |
| `fail_streak` | 연속 gate-verify FAIL 횟수 (5 이상 → STUCK_<phase>) |

---

## 폐기된 phase (사용 금지)

아래 phase 명은 이전 설계에서 사용되었으나 **현재 하네스에서 폐기**되었다.
ralph-tick 또는 어떤 스킬도 이 값으로 전이해선 안 된다.

| 폐기 phase | 폐기 사유 |
|------------|-----------|
| `RESEARCH` | INTAKE + CHUNK_DETAIL 로 대체됨. 시장조사는 INTAKE 내 sub-step 으로 흡수. |
| `IDEATION` | INTAKE 산출물 기반 ideation 은 CHUNK_DETAIL 내에서 처리. 별도 phase 불필요. |
| `IMPLEMENT_PENDING_FREEZE` | SPEC → IMPLEMENT 전이 게이트로 spec-frozen.flag 체크 방식으로 대체. 별도 phase 없음. |
| `FIXING_QA` | QA_REVIEW 내부 루프에서 직접 IMPLEMENT 로 전이. 별도 phase 없음. |
| `FIXING_COUNCIL` | REVIEW_COUNCIL 내부 루프에서 직접 IMPLEMENT 로 전이. 별도 phase 없음. |
| `FIXING_GAP` | GAP_ANALYSIS 내부 루프에서 직접 IMPLEMENT 로 전이. 별도 phase 없음. |
| `FIXING_CHECK` | CHECKLIST 내부 루프에서 직접 IMPLEMENT 로 전이. 별도 phase 없음. |
