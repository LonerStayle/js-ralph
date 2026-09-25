---
description: "일시정지 · 차단 · 세션 종료로 멈춘 feature 실행을 이어서 진행합니다."
argument-hint: "[차단 노드에 대한 결정 — 선택]"
allowed-tools: ["Bash(bash .harness/bin/harness.sh:*)"]
---

# Resume

```!
bash .harness/bin/harness.sh status
```

1. 위 출력이 "활성 run 없음" 이면: 이어갈 feature 가 없다고 안내하고 `/js-ralph:feature` 를 권합니다.
2. 사용자 입력(`$ARGUMENTS`)이 있으면 차단 노드에 대한 결정으로 취급합니다. TREE.md 의 해당 `[!]` 노드 아래 `> 결정: …` 로 기록하고
   `bash .harness/bin/harness.sh set <id> todo` 로 되돌립니다. 결정이 SPEC 의 가정을 바꾸면 SPEC.md 의 `가정` 도 고칩니다.
3. 입력 없이 `[!]` 노드만 남아 있으면: 각 차단 사유를 3줄 이내로 보여주고 결정을 요청한 뒤 멈춥니다 (재개하지 않음).
4. 재개: `bash .harness/bin/harness.sh resume` 실행 후 `feature-orchestration` 스킬을 불러 **Phase B** 부터 이어갑니다.
