---
description: "진행 중인 feature 실행을 일시정지합니다 (Stop 가드 해제). 재개는 /resume."
allowed-tools: ["Bash(bash .harness/bin/harness.sh:*)"]
---

# Pause

```!
bash .harness/bin/harness.sh pause && bash .harness/bin/harness.sh status
```

진행 중이던 노드가 `[~] doing` 이면 그대로 둡니다 — 재개 시 그 노드부터 이어갑니다.
위 결과를 짧게 보고하고, 재개는 `/js-ralph:resume` 이라고 안내하십시오. 추가 작업은 하지 마십시오.
