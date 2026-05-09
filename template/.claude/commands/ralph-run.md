---
description: ralph 자율 사이클 시작 (한 단어). ralph-loop 플러그인의 setup 스크립트를 직접 bash 호출 — 슬래시 커맨드 wrapper 가 아니라 setup 단계만 그대로 재현해서 권한 모델과 충돌 없음. Stop hook 은 플러그인이 이미 등록해둔 그대로 활성.
allowed-tools: ["Bash(bash ~/.claude/plugins/cache/claude-plugins-official/ralph-loop/*/scripts/setup-ralph-loop.sh:*)"]
---

ralph-loop 플러그인의 setup-ralph-loop.sh 를 직접 호출해 자율 루프 활성화.

```!
bash ~/.claude/plugins/cache/claude-plugins-official/ralph-loop/*/scripts/setup-ralph-loop.sh "ralph-tick 스킬에 따라 현재 phase 의 1 step 만 진행. 절차: (1) .claude/state/ralph-status.md 의 cycle/phase 읽기 (2) ralph-tick 디스패치 표대로 정확히 1 step (두 step 묶음 금지) (3) gate-verify 해당 시 실행 (4) status 갱신 + ralph-history.md append (5) PROJECT_DONE 도달 시에만 마지막 줄에 정확히 <promise>PROJECT_DONE</promise> 출력. 거짓 promise 금지. spec-auto-freeze.flag 없이 IMPLEMENT_PENDING_FREEZE 면 noop. STUCK_<phase> 면 noop." --completion-promise "PROJECT_DONE" --max-iterations 300
```

setup 스크립트가 끝나면:
- `.claude/ralph-loop.local.md` 생성됨 (state file)
- ralph-loop 플러그인의 Stop hook 이 다음 종료 시도부터 자동 가로채서 같은 prompt 재투입
- `<promise>PROJECT_DONE</promise>` 또는 max-iterations 도달까지 끊김 없음
- 중단: `/cancel-ralph`
