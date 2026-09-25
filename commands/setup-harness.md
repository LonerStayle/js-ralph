---
description: "현재 디렉토리에 롱러닝 무인 코딩 하네스를 세팅하고 비전 인터뷰(vision-intake)를 즉시 시작합니다."
argument-hint: "[--overlay] [--force]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-harness.sh:*)"]
---

# Setup Harness

플러그인이 동봉한 하네스 파일(`CLAUDE.md`, `.harness/`, `.claude/`)을 현재 디렉토리에 설치합니다.

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-harness.sh" $ARGUMENTS
```

위 스크립트가 exit 0 이면 **같은 턴 안에서 즉시** `vision-intake` 스킬을 Skill 도구로 호출해 비전 인터뷰를 시작하십시오 (사용자 추가 발화 불필요).

exit != 0 (충돌 파일 존재 / 동결된 비전 보호 / 잘못된 디렉토리 / jq 없음) 이면 vision-intake 를 호출하지 말고, 출력된 안내문을 그대로 사용자에게 전달하십시오.
