---
name: project-stop-check
description: CYCLE_DONE 직후 자동 호출. CLAUDE.md "프로젝트 종료 조건" 을 누적 산출물 + 측정 지표와 대조해 PROJECT_DONE 여부 판정.
---

# project-stop-check

## 입력
- `CLAUDE.md` 의 "프로젝트 종료 조건 (STOP)" 섹션 (비용 cap / 가치 cap / 예외 cap)
- `.claude/state/current-cycle` (현재 사이클 번호)
- `.claude/state/cycles/0..N/done.md` (각 사이클 종료 메모)
- 도메인 측정 지표 (가능하면 코드/로그/DB 에서 직접 확인)

## 절차

1. 비용 cap 채점
   - cycles 누적 ≥ N 이면 STOP
2. 가치 cap 채점
   - 명시된 정량 기준 각각에 대해 PASS / FAIL / UNKNOWN
   - UNKNOWN 은 즉시 검증 명령 (테스트/grep/Read/SQL) 자동 시도
3. 예외 cap
   - 사용자가 `/ralph-stop` 으로 명시 종료한 흔적이 있는가
4. 합산
   - 비용 cap OR 가치 cap (모두 PASS) OR 예외 cap → STOP
   - 그 외 → CONTINUE

## 출력

`.claude/state/cycles/<N>/stop-check.md`:

```
## project-stop-check <ISO ts>
### 비용 cap
- cycles=N, limit=M → PASS|FAIL
### 가치 cap
- [PASS] 지표 X ≥ Y (현재 Z, 7일 연속) — 근거
- [FAIL] 지표 W ≥ V (현재 U) — 추가 사이클 필요
### 결론: STOP | CONTINUE
```

`.claude/state/ralph-status.md`:
- STOP → `phase=PROJECT_DONE`. 이후 `/ralph-cycle-start` 는 안내 메시지 출력 후 차단.
- CONTINUE → `phase=CYCLE_DONE` 유지. 사용자가 `/ralph-cycle-start` 로 다음 사이클 진입.

## 금지

- 근거 없는 "곧 충족될 것 같다" 식 발언 금지. 정량 기준 vs 측정값으로만 판정.
