---
description: "기획 한 건을 넣으면 영향 분석 → 모듈 트리 설계 → 바텀업 구현 → 검증 → 보고까지 무인으로 끝까지 진행합니다."
argument-hint: "<기획 — 자유 텍스트, 길어도 됨>"
---

# Feature

사용자 기획:

```
$ARGUMENTS
```

## 사전 확인 (하나라도 실패하면 중단하고 안내)

1. `.harness/bin/harness.sh` 와 `CLAUDE.md` 가 있어야 합니다. 없으면: "하네스가 없는 디렉토리입니다. `/js-ralph:setup-harness` 부터 진행하십시오."
2. `CLAUDE.md` 가 `onboarded: true` 여야 합니다. 아니면 vision-intake 스킬로 비전 인터뷰부터 진행합니다 (이 기획은 인터뷰 후 이어서 처리).
3. 위 기획 텍스트가 비어 있으면: "기획을 함께 적어 주십시오. 예) `/js-ralph:feature 회원가입에 이메일 인증 추가. 인증 메일 10분 만료, 재발송 1분 쿨다운.`"
4. `bash .harness/bin/harness.sh status` 가 다른 feature 를 `running` 으로 보이면: 그 feature 를 계속할지(`/js-ralph:resume`), 멈추고 새 기획을 시작할지(`/js-ralph:pause` 후 다시 `/js-ralph:feature`) 물어봅니다.
5. 기획이 CLAUDE.md 의 "5. 금지 / 범위 밖" 과 정면 충돌하면 진행하지 않고 그 사유를 보고합니다.

## 실행

`feature-orchestration` 스킬을 Skill 도구로 불러 **Phase A 부터** 위 기획으로 끝까지 진행하십시오.
계획이 확정되면 사용자 승인을 기다리지 않고 구현으로 넘어갑니다. 중간 보고는 짧게 하고 멈추지 않습니다.
