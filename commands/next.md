---
description: "다음에 만들 기능을 세 시야(사용자 · 전문가 · 만드는 사람)에서 제안받아 카드로 보여줍니다."
allowed-tools: ["Bash(bash .harness/bin/harness.sh:*)"]
---

# Next

```!
bash .harness/bin/harness.sh status; bash .harness/bin/harness.sh proposal status
```

- 하네스가 없거나(`.harness/` 부재) 비전이 동결 전이면(CLAUDE.md `onboarded: false`) 그 사실을 안내하고 멈추십시오.
- 진행 중인 feature 가 `running` 이면: 그 feature 를 끝낸 뒤 자동으로 제안된다고 안내하고 멈추십시오.
- 그 외에는 `next-proposals` 스킬을 Skill 도구로 불러 절차대로 진행하십시오.
