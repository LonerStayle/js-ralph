---
description: "v3-classic ralph 하네스를 현재 디렉토리에 박고 vision-intake 비전 인터뷰를 즉시 시작합니다."
argument-hint: "[--overlay] [--force]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph.sh:*)"]
---

# Setup Ralph (v3-classic 하네스 세팅)

플러그인이 동봉한 5파일 + 부속 파일을 현재 디렉토리에 박고, vision-intake skill 을 즉시 invoke 합니다.

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph.sh" $ARGUMENTS
```

세팅이 끝나면 (위 bash 가 exit 0) **즉시 다음을 수행하십시오** (D-2: vision-intake 즉시 트리거, 같은 turn 안):

1. `vision-intake` skill 을 Skill 도구로 invoke 합니다 (사용자 별도 발화 불필요).
2. vision-intake skill 본문의 1단계 "인사" → 2단계 "8 질문" 흐름이 자동 시작됩니다.
3. 5단계 "동결" + 6단계 "ralph-loop 자동 시작 게이트 (FR-7)" 까지 완주합니다.

bash 가 exit != 0 (clean 모드 충돌 / overlay 비전 보호 abort / 잘못된 디렉토리 등) 이면 vision-intake invoke 하지 마시고, stderr 에 출력된 안내문 그대로 대표님께 보고하십시오.
