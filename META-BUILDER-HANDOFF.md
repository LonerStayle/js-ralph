# META-BUILDER HANDOFF — skill 자동생성 빌더

> 별도 플러그인에 만들 **`/new-skill`** 빌더 인수인계 문서.
> 다른 세션에서 작업 시작할 때 그대로 읽으면 되도록 자가완결로 작성됨.
> 작업 완료 후 본 파일은 폐기 가능.

---

## 1. 목표

대표님의 **별도 플러그인** (js-ralph 와 별개) 에 슬래시 하나 추가:

| 빌더 | 입력 | 출력 |
|------|------|------|
| **`/new-skill`** (가칭) | 자유 텍스트 — "이런 skill 을 만들어줘" | `skills/<slug>/SKILL.md` 한 장 (frontmatter + 본문 instruction) |

핵심 디자인 — **사용자가 한 줄 던지면 잘게 분해해서 완성된 .md 한 장 떨궈주는 방식**. js-ralph 의 `/expand-plan` 과 같은 "알잘딸깍센" 컨셉.

---

## 2. 왜 skill 만? (command 자동생성은 의도적 제외)

2026-05-25 세션에서 공식 docs + WebSearch 로 검증한 사실:

| 종류 | hot-reload | 메뉴 노출 |
|------|------------|-----------|
| **`skills/<name>/SKILL.md`** | ✅ **즉시** (저장 즉시 사용 가능) | ✅ 자동 (`user-invocable: false` 로 숨김 가능) |
| `commands/*.md` | ⚠️ 새 세션 또는 `/reload-plugins` 필요 (공식 hot-reload 미지원, GitHub issue #20507/#23385 미해결) |

→ **command 빌더는 reload 마찰이 있어 UX 가 한 단계 무거워짐.** skill 빌더는 만들자마자 바로 쓸 수 있어 "빌더로 자동화하는 의미" 가 명확함. 그래서 command 자동생성은 빼고 skill 만 채택.

(빌트인 인터랙티브 UI 는 command/skill 어느 쪽에도 없음 — `/agents` 는 sub-agent 전용. 출처: https://code.claude.com/docs/en/agent-sdk/slash-commands)

---

## 3. Skill 파일 스펙 (`skills/<slug>/SKILL.md`)

```markdown
---
name: <slug>
description: "이 skill 이 언제 발동돼야 하는지 — Claude 가 이 description 보고 자동 발동 여부 판단. 1줄 권장."
user-invocable: true   # 기본 true. /menu 노출 여부
---

# 본문 (제목 자유)

skill 본문 instruction. 슬래시 호출 (`/<slug>`) 시 + Claude 가 자동 트리거 시 둘 다 이 본문이 LLM 에게 로드됨.
```

**핵심 동작**:
- **슬래시 호출** — 사용자 명시 `/<slug>` → 본문 로드
- **자동 발동** — Claude 가 description 보고 "지금 발동해야겠다" 판단 시 자동 로드
- description 이 발동 게이트 역할 — 짧고 구체적이어야 잘못된 발동을 막을 수 있음

---

## 4. `/new-skill` 빌더 기능 명세 (제안 — 다른 세션에서 합의 후 구현)

### 입력
- `$ARGUMENTS` = 자유 텍스트. 예: "사용자가 'X 해줘' 라고 말하면 자동으로 발동돼서 Y 와 Z 를 차례로 수행하는 skill"

### 자동 분해 로직
1. 입력에서 **자동 발동 트리거 조건** 추출 — description 의 핵심 (Claude 가 이걸 보고 발동 결정)
2. 입력에서 **수행 동작** 추출 — 본문 instruction (bite-sized step 1~7 단계)
3. 슬러그 자동 생성 (영문 kebab-case)
4. `user-invocable` 결정 — 입력에 "메뉴에 띄우지 마" 같은 단서 있으면 false, 기본 true
5. `skills/<slug>/SKILL.md` Write

### 완료 후 보고
```
✅ /<slug> skill 이 <경로> 에 생성되었습니다.

발동 조건: <description 1줄 요약>

저장 즉시 사용 가능합니다 (skill hot-reload).
- 사용자 명시 호출: /<slug>
- 자동 발동: Claude 가 description 매칭 판단 시
```

### 금지
- description 을 1줄 이상 늘리지 마라 — Claude 의 발동 판단 비용 증가 + 오발동 위험
- 동일 이름 skill 덮어쓰기 금지 (`--force` 옵션 없으면 abort + 기존 파일 안내)
- skill 본문에 비밀값/토큰/하드코딩된 경로 박지 마라

---

## 5. 참고할 패턴 — js-ralph 의 expand-plan.md

본 저장소 (`/Users/goldenplanet/jinsup_space/js-ralph`) 의 `commands/expand-plan.md` 가 동일 디자인의 instruction-only 빌더 패턴:

- frontmatter (description + argument-hint) + 본문 instruction
- bash 호출 없이 LLM 이 직접 Read / Edit / 분해 / Write 까지 한 턴에 수행
- "알잘딸깍센 분해 로직" 의 instruction 작성 방식

→ **`/new-skill` 빌더는 `expand-plan.md` 형식 (instruction-only) 으로 만드는 게 자연스러움.**

(빌더 자체는 command 로 만든다. skill 로 만들면 자동 발동되어 "사용자가 평소 대화에서 skill 만들어달라고 안 했는데도 발동" 사고가 날 수 있음 — 빌더 같은 메타 도구는 명시 호출만 받는 게 안전.)

---

## 6. 다른 세션 출발 prompt (copy-paste 용)

다른 플러그인 작업할 세션에 이 prompt 그대로 던지면 됨:

```
/Users/goldenplanet/jinsup_space/js-ralph/META-BUILDER-HANDOFF.md 를 먼저 읽어줘.

내 별도 플러그인에 그 문서의 §4 명세대로 /new-skill 슬래시를 추가하고 싶어.

§5 의 expand-plan.md 형식 (instruction-only, bash 없음) 으로 만들어줘.
빌더 자체는 command (commands/new-skill.md) 로 만든다.
플러그인 위치는 (← 본인이 알려줄 것).

진행 전에 §4 의 분해 로직 / 금지 / 보고 형식 중에 추가/수정할 거 있는지 물어봐줘.
```

---

## 7. 결정 대기 항목 (다른 세션에서 합의)

- [ ] 슬래시 이름 확정 — `/new-skill` vs `/create-skill` vs `/scaffold-skill` 등
- [ ] 슬러그 자동생성 규칙 — 입력의 명사구 추출? 사용자가 첫 인자로 명시?
- [ ] `--force` 옵션 추가 여부 (덮어쓰기 허용)
- [ ] 빌더가 새 skill 을 박는 기본 위치 — 자기 플러그인 안 (`<plugin-root>/skills/`) / 프로젝트 (`.claude/skills/`) / 글로벌 (`~/.claude/skills/`) 중 어느 거?
- [ ] 생성된 skill 의 description 자동 검증 — 길이 / 트리거 명확성 휴리스틱
- [ ] dry-run 옵션 — 실제 Write 전에 미리보기

---

## 8. 본 문서 폐기 시점

`/new-skill` 빌더 만들고 동작 확인되면 이 파일 삭제 가능.
또는 빌더 플러그인 저장소로 옮겨서 거기 README 일부로 흡수.
