# 🗃️ 카드 보관소 (MVP)

중저가(시세 ₩100,000 이하) 포켓몬 카드를 **실물로 맡기고, 배송 없이 소유권만 사고파는** 보관·거래 플랫폼 MVP입니다.
고가 카드는 PSA 등 기존 그레이딩 기관에 맡기고, 여기서는 거래가 어려웠던 중간 가격대 카드만 다룹니다.

## 흐름
1. **입고 신청** — 회원이 카드를 검색해 최대 10장을 배치에 담고 각 카드의 컨디션(S/A/B/C)을 스스로 매깁니다.
   담은 순서대로 슬리브 1~10번에 넣고 배치 코드 쪽지와 함께 발송합니다.
2. **입고 검수** — 운영자가 슬리브 순서대로 신청 내용과 대조합니다.
   - 일치 → 신청 등급으로 보관함 등록
   - 하향 → 낮춘 등급으로 등록 (더 높게는 못 올림)
   - 불일치(바꿔치기 의심) → 등록 안 됨, 신뢰 점수 −10 · 누락 → 등록 안 됨
3. **거래** — 보관함 카드를 마켓에 올리고, 다른 회원이 포인트로 사면 소유권만 즉시 넘어갑니다. 판매 수수료 5%.
4. **출고** — 보관 중인 카드를 골라 한 번에 받습니다 (배송비 ₩3,000).
5. **포인트** — MVP는 입금 확인 후 운영자가 수동 충전합니다 (음수 금액 = 출금 처리). 모든 변동은 원장(ledger)에 남습니다.

## 보안 구조
- 모든 테이블에 RLS를 켜고 테이블 권한을 회수했습니다. 브라우저는 테이블을 직접 읽거나 쓸 수 없고,
  `security definer` 서버 함수(RPC)만 호출할 수 있으며 함수 안에서 `auth.uid()`로 본인 확인·운영자 확인을 합니다.
- 구매는 행 잠금(`for update`)으로 동시 구매 시 한 명만 성공합니다.
- 브라우저에 들어가는 키는 공개용 **anon key**뿐입니다. `service_role` 키는 절대 `config.js`에 넣지 마세요.

## 설정 (10분)
1. [supabase.com](https://supabase.com)에서 무료 프로젝트를 만듭니다.
2. **SQL Editor**에 `supabase/schema.sql` 전체를 붙여 넣고 실행합니다.
3. **Authentication → URL Configuration**의 Site URL(과 Redirect URLs)에 이 페이지 주소를 넣습니다.
   예: `https://tube10081008-stack.github.io/-/vault/`
4. **Project Settings → API**의 Project URL과 anon public key를 `config.js`에 넣고, 보낼 주소(`shipTo`)와 입금 안내(`depositInfo`)도 적습니다.
5. 페이지에서 이메일로 로그인한 뒤, SQL Editor에서 내 계정을 운영자로 바꿉니다:
   ```sql
   update profiles set role = 'admin' where id = (select id from auth.users where email = '내이메일');
   ```

수수료·상한가·배치 장수·배송비는 `schema.sql` 맨 위 `cfg_*` 함수에서 바꿉니다.

## 파일
- `index.html` — 앱 전체 (마켓 · 보관함 · 입고 · 지갑 · 운영)
- `config.js` — Supabase 주소/anon key, 운영 안내 문구
- `supabase/schema.sql` — 테이블 · RLS · 서버 함수

## 아직 안 한 것
- 결제 연동(현재 수동 충전), 스캐너 앱과 입고 연동(스캔 지문 자동 대조), 판매 알림
