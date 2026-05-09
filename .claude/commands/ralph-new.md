---
description: template/ 을 복제해 새 ralph 하네스를 ~/jinsup_ralph/<name>/ 에 eject 하고 git init 까지 자동 수행한다.
argument-hint: <name>
---

`scripts/new-harness.sh $1` 을 실행한다.

이 스크립트는 다음을 자동 수행:
1. `${RALPH_HOME:-$HOME/jinsup_ralph}/$1/` 생성 + template 복제
2. CLAUDE.md / README.md 의 `{{PROJECT_NAME}}` 치환
3. `git init -b main` + 초기 커밋

실행 후 사용자에게 안내:
1. `cd ~/jinsup_ralph/$1`
2. `.claude/scripts/{deploy,smoke-test}.sh` 도메인 명령으로 채우기
3. `.claude/config/verify-checklist.md` 도메인 항목 추가
4. `CLAUDE.md` 도메인 섹션(무엇/입력/산출물/종료조건) 채우기
5. `/ralph-deploy` → `/ralph-cycle-start` 로 첫 사이클 시작

원격 저장소가 필요하면 (선택):
```
gh repo create $1 --private --source=. --remote=origin --push
```
