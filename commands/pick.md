---
description: "제안 카드 하나를 골라 기획으로 진행합니다. 수정 사항을 뒤에 붙일 수 있습니다."
argument-hint: "<C번호> [수정 사항 — 선택]"
allowed-tools: ["Bash(bash .harness/bin/harness.sh:*)"]
---

# Pick

입력: `$ARGUMENTS`

1. 첫 단어가 카드 번호(`C1`, `c2` 등 → 대문자로)입니다. 없으면 `bash .harness/bin/harness.sh proposal status` 와 카드 목록을 보여주고 고르도록 안내한 뒤 멈추십시오.
2. `bash .harness/bin/harness.sh proposal choose <C번호>` — 실패하면(대기 중인 제안 없음 / 없는 카드) 출력 그대로 안내하고 멈추십시오.
   이 선택으로 자동 진행 연속 카운터가 0 으로 돌아갑니다.
3. 카드 번호 뒤의 나머지 텍스트는 **수정 사항** 입니다. `next-proposals` 스킬의 4번 절차대로, 카드의 `기획:` 문장에 수정 사항을 합쳐
   `feature-orchestration` 을 Phase A 부터 진행하십시오. 수정 사항이 카드와 충돌하면 수정 사항이 이깁니다.
