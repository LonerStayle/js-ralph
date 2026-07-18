---
description: "현재 세션에서 goal 루프(자기 재투입)를 시작합니다."
argument-hint: "GOAL [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/goal-loop.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Goal (자기 재투입 루프 시작)

goal 루프 상태 파일을 만들어 이 세션에 self-referential 루프를 켭니다.

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/goal-loop.sh" $ARGUMENTS
```

작업을 진행하십시오. 종료를 시도하면 goal 루프가 **SAME PROMPT** 를 다음 iteration 으로 다시 넣어 줍니다. 이전 작업은 파일과 git 히스토리에 남아 있어, 매 iteration 그것을 보고 반복적으로 개선하게 됩니다.

CRITICAL RULE: completion promise 가 설정돼 있으면, 그 진술이 **완전하고 명백하게 참일 때만** 출력하십시오. 막혔다고 느끼거나 다른 이유로 나가고 싶어도, 루프를 탈출하려고 거짓 promise 를 출력하지 마십시오. 이 루프는 진짜 완료까지 이어지도록 설계돼 있습니다.

수동 중단은 `/cancel-goal` 입니다.
