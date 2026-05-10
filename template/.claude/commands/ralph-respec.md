---
description: master-spec 갱신 후 INTAKE 재실행 트리거 (R-8 idempotency 우회)
---

master-spec.md 를 사람이 직접 수정한 후 호출. manifest.md 를 비우고 INTAKE phase 로 재진입한다.
주의: 진행 중 chunk 상태가 사라질 수 있음. 백업 후 사용 권장.
