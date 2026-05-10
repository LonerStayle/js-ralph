# ralph-v2 롤아웃 가이드

작성: 2026-05-10
대상: js-ralph factory v2 patch 적용 후 사용자 (대표님)
선행: factory patch 완료 (CH-20260510-001 ~ 003 + 14 task commits)

---

## 1. e2e 검증 (AC-4)

신규 하네스 1개를 eject → onboarding → INTAKE → cycle 1 chunk 1 자율 완주 (코드까지) 까지 한 번 통과해야 v2 가 동작 검증된다.

### 절차

```bash
# 1. 신규 하네스 eject
cd /Users/goldenplanet/jinsup_space/js-ralph
bash scripts/new-harness.sh test-v2

# 2. 디렉터리 이동 + 새 Claude 세션
cd ~/jinsup_ralph/test-v2
claude
```

### 진입 후 자동으로 일어나는 일

1. ralph 가 즉시 인사: **"대표님 안녕하십니까. 이 프로젝트의 비전과 지시사항을 주십시오."**
2. ralph 가 onboarding 8 질문을 1개씩 드림 (catalog 는 `template/CLAUDE.md` 참조)
3. 대표님 답변 → ralph 가 `.claude/state/intake/master-spec.md` 합성
4. 대표님이 "확정" / "OK" / "진행해" 발화 → master-spec 동결
5. INTAKE phase 자동 전이 → ralph 가 chunk 분해 → `manifest.md` 생성
6. CHUNK_DETAIL → SPEC → IMPLEMENT → QA → COUNCIL → GAP → CHECKLIST 자율 진행
7. CYCLE_DONE 시 Telegram 알림 1회 (chat_id 설정된 경우)

### 검증 통과 기준

- ralph 가 자동 인사 발화함
- 8 질문 인터뷰 진행됨
- master-spec 동결 후 INTAKE 자동 전이됨
- chunks/<i>.md + manifest.md 자동 생성됨
- cycle 1 의 chunk 1 이 IMPLEMENT phase 까지 자율 진행됨 (코드 1+ 라인 작성)
- CYCLE_DONE 도달 시 Telegram 알림 1회 발사됨 (chat_id 설정된 경우)

### 실패 시

- onboarding 인사 발화 안 됨 → ralph-tick 의 NOT_STARTED phase 동작 확인
- chunks 분해 결과 의도와 어긋남 → master-spec 보강 후 `/ralph-respec`
- Telegram 알림 발사 실패 → `.claude/state/notifications.log` fallback 확인
- BLOCKED chunk 50% 초과 → master-spec 갱신 권장

---

## 2. show-money 마이그레이션 (선택, out-of-scope)

show-money 는 v1 기준 cycle 6 PROJECT_DONE 상태이다. v2 마이그레이션은 본질적으로 새 master-spec 작성이라 새 프로젝트와 동등하다. 사용자가 별도 결정 시 아래 절차:

### 절차

```bash
# 1. 백업
cp -R ~/jinsup_ralph/show-money ~/jinsup_ralph/show-money.v1.bak

# 2. v2 template 으로 .claude/ 일부 갱신 (수동 cp)
#    아래 디렉터리를 v2 template/.claude/ 에서 복사:
#    - skills/{onboarding,phase-intake,chunk-detail,notify-sender}/
#    - skills/{ralph-tick,gate-verify,gap-analysis,project-stop-check,review-council,phase-implement,phase-spec}/
#    - state/intake/  (기존 cycles/ 는 보존)
#    - config/notify.md
#    - 폐기: skills/{phase-research,ideation-council}/, commands/ralph-{research,ideation,spec}-done.md, commands/ralph-cycle-start.md
#    - 갱신: commands/ralph-run.md, commands/ralph-respec.md (신규)
#    - agents/ 페르소나 톤 갱신 (대표님 호칭)

# 3. 새 master-spec.md 작성 (postmortem priority 1~4 반영)
#    - LLM 파이프라인 (URL 진위 / 본문 추출 / 광고 분류)
#    - 도메인 좁히기 (5 카테고리 → 1 카테고리)
#    - UX 라벨 시각 피드백 + 다음 카드 노출
#    - STOP 재정의 (실사용자 메트릭 X, chunk 소진 기준)

# 4. 동결 후 INTAKE 재진입
/ralph-respec   # manifest 비우고 INTAKE 재실행
```

### 권장하지 않는 경우

- show-money 가 운영 단계 가까이 와 있다면 그대로 v1 으로 운영 후 측정 단계로 이동
- v2 에서 같은 도메인을 다시 키우려면 `bash scripts/new-harness.sh show-money-v2` 로 신규 하네스 만드는 게 깔끔할 수 있음

---

## 3. v1 ↔ v2 호환 (R-10)

폐기 슬래시 커맨드는 v2 에서 즉시 삭제됐다. 기존 하네스 (show-money / GodMode / PlanB / 기타) 가 호출 시 깨진다.

### 폐기 커맨드 목록

| 커맨드 | 대체 |
|--------|------|
| `/ralph-research-done` | 폐기 (RESEARCH phase 제거됨, CHUNK_DETAIL 통합) |
| `/ralph-ideation-done` | 폐기 (IDEATION phase 제거됨, CHUNK_DETAIL 통합) |
| `/ralph-spec-done` | 폐기 → master-spec 동결로 대체 / 갱신은 `/ralph-respec` |
| `/ralph-cycle-start` | 폐기 (자동 진행으로 대체) |

### 폐기 phase 목록

| Phase | 대체 |
|-------|------|
| RESEARCH | CHUNK_DETAIL 통합 |
| IDEATION | CHUNK_DETAIL 통합 |
| IMPLEMENT_PENDING_FREEZE | 제거 (master-spec 이 곧 frozen) |
| FIXING_QA / FIXING_COUNCIL / FIXING_GAP / FIXING_CHECK | 제거 (FAIL 시 IMPLEMENT 직회귀) |

### 사용자 책임

기존 v1 하네스를 v2 로 갈아탈지 그대로 둘지는 사용자 판단. 작은 v1 하네스는 그대로, 큰 자산이 있으면 §2 마이그레이션 가이드 참조.

---

## 4. 정적 검증 (CI/배포 전 1회)

template patch 가 정상 적용됐는지 자동 grep 검증:

```bash
bash scripts/verify-v2-template.sh
```

기대 출력: `verify-v2-template: ALL PASS`

검사 항목:

- 6원칙 매핑 표 (7원칙 부재)
- INTAKE / CHUNK_DETAIL phase 정의 존재
- 신규 4 skill 디렉터리 존재
- 폐기 2 skill 부재
- state/intake/ placeholder + config/notify.md 존재
- 15 페르소나 모두 "대표님" 키워드
- 폐기 4 슬래시 커맨드 부재

---

## 5. 운영 첫 24시간 점검 항목

신규 하네스 첫 cycle 진행 중 확인할 것:

| 점검 | 위치 | 기대 |
|------|------|------|
| Telegram 알림 발사 | Telegram 채팅 또는 `.claude/state/notifications.log` | CYCLE_DONE 마다 1회 |
| 대표님 reply 폴링 | `.claude/state/inbox/<timestamp>.md` | reply 시점에 파일 생성 |
| dispatch_count 증가 | `.claude/state/intake/manifest.md` | 매 cycle 진짜 dispatch 후 +1 |
| BLOCKED 비율 | manifest.md 진행 표 | ≥50% 시 PROJECT_DONE 강제 |
| runtime evidence 자동 검증 | `.claude/state/cycles/<N>/runtime-evidence.md` | CHECKLIST 통과 전 필수 |

이상 발생 시:
- Telegram 발사 실패 → notify.md 의 chat_id 확인
- BLOCKED chunk 다수 → master-spec 보강 후 `/ralph-respec`
- runtime-evidence 미작성 → `.claude/scripts/runtime-evidence.sh` 도메인 채움 또는 수동 캡처

---

## 6. 알려진 제한 사항

- **chunk 분해 review 게이트 없음** (Q3 결정): cycle 1 까지 가서야 잘못된 분해 발견 가능. 완화 = AC-4 e2e 검증
- **STUCK chunk timeout 없음** (NFR-3): 대표님 reply 가 며칠 늦어도 ralph 는 다른 chunk 진행. max-iterations 300 cap 만 작동
- **Gmail / Slack / Telegram 외 채널 미지원**: Telegram MCP 단일 (Q4 결정)
- **사람 chunk 마커 미지원**: master-spec 자유 prose 만 (Q2 결정)
- **autoCompact 자동 압축 의존**: 컨텍스트 한계 시 자동 압축. 사용자 글로벌 설정 영향 받음

---

## 7. 다음 작업 후보 (out-of-scope, 운영 단계)

- **sync-from-factory 스크립트**: template 갱신 시 기존 eject 된 하네스를 자동 동기화 (현재는 수동 cp)
- **chunk 분해 도메인별 휴리스틱**: 일반 LLM 분해를 도메인 학습 분해로
- **Telegram 응답 SLA 메커니즘**: timeout 후 best-guess 시도 옵션
- **Gmail 백업 채널**: Telegram 끊김 시 fallback
- **CI 통합**: verify-v2-template.sh + AC-4 e2e 자동화

---

## 8. 참고

- `docs/features/2026-05-10-ralph-v2/ralph-v2-requirements.md` (PRD)
- `docs/features/2026-05-10-ralph-v2/ralph-v2-tech-design.md` (tech-design)
- `docs/features/2026-05-10-ralph-v2/ralph-v2-implementation-plan.md` (plan)
- `docs/factory-redesign-requirements.md` (8개 변경 요구사항 원본)
- `docs/redesign-external-master-spec.md` (외부 master-spec 모델 설계)
- `~/jinsup_ralph/show-money/docs/lessons/` (postmortem 5함정 원본)

---

_End. v2 patch 완료 검증 후 본 가이드를 운영 단계 reference 로 사용._
