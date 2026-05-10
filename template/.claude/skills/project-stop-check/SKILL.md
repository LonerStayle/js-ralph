---
name: project-stop-check
description: CYCLE_DONE 직후 자동 호출. manifest.md 의 chunk 소진 여부 + BLOCKED 비율 + 비용 cap 을 대조해 PROJECT_DONE 또는 CONTINUE 판정.
---

# project-stop-check

## 입력
- `.claude/state/intake/manifest.md` (chunk 목록 + 각 chunk status)
- `.claude/state/cycles/<N>/` 각 사이클의 CHECKLIST 결과
- `.claude/state/ralph-status.md` (현재 cycle, phase)
- `master-spec.md` 비용 cap (있으면)

## 절차

1. **chunk 소진 채점**
   - `manifest.md` 의 모든 chunk status 확인
   - 모든 chunk 가 `DONE` 또는 `BLOCKED` → 소진 조건 충족
   - `PENDING` 또는 `IN_PROGRESS` 가 1개라도 있으면 → 소진 조건 불충족

2. **DONE chunk 품질 채점**
   - DONE 상태인 chunk 들이 각 cycle 의 CHECKLIST PASS 기록을 갖고 있는가
   - `cycles/<N>/gate-verifies.md` 에서 CHECKLIST PASS 기록 확인
   - DONE 이지만 CHECKLIST PASS 기록 없는 chunk → 재검증 또는 FAIL

3. **BLOCKED 비율 채점**
   - `BLOCKED chunk 수 / 전체 chunk 수 ≥ 50%` → 자동 STOP (R-3 완화)
   - BLOCKED 과다 시 → status=PROJECT_DONE + Telegram 으로 개입 요청 전송

4. **비용 cap 채점**
   - master-spec 에 명시된 cycle 수 cap 또는 비용 cap 이 있으면 확인
   - 현재 cycle ≥ cap → STOP 조건 충족

5. **합산**
   - (모든 chunk DONE/BLOCKED + DONE chunk 전부 CHECKLIST PASS) OR (BLOCKED ≥ 50%) OR (비용 cap 도달) → STOP
   - 그 외 → CONTINUE

## 출력

`.claude/state/cycles/<N>/stop-check.md`:

```
## project-stop-check <ISO ts>
### chunk 소진
- DONE: X개, BLOCKED: Y개, PENDING/IN_PROGRESS: Z개
- 소진 여부: PASS|FAIL
### DONE chunk 품질
- CHECKLIST PASS 확인: X/X → PASS|FAIL
### BLOCKED 비율
- blocked_ratio: Y/(X+Y) = N% → PASS(≥50% auto-STOP)|BELOW_THRESHOLD
### 비용 cap
- cycles=N, limit=M → PASS|FAIL|N/A
### 결론: STOP | CONTINUE
- STOP 사유: chunk_exhausted | blocked_ratio_cap | cost_cap | user_stop
```

`.claude/state/ralph-status.md`:
- STOP → `phase=PROJECT_DONE`. `/ralph-run` 재호출 시 PROJECT_DONE 안내 출력 후 차단.
- CONTINUE → `phase=CYCLE_DONE` 유지. 다음 PENDING chunk → CHUNK_DETAIL 자동 진입.

## PROJECT_DONE 시 후처리

1. `ralph-status.phase = PROJECT_DONE` 기록
2. `notify-sender` (Telegram) 로 PROJECT_DONE 보고 전송 (대표님 톤)
3. BLOCKED ≥ 50% 로 인한 STOP 시 Telegram 메시지에 개입 요청 포함

## 금지

- 근거 없는 "곧 충족될 것 같다" 식 발언 금지. chunk status + CHECKLIST 기록으로만 판정.
- manifest.md 확인 없이 PROJECT_DONE 선언 금지.
