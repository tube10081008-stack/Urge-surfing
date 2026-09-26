-- =====================================================================
-- 카드 보관·거래 MVP (중저가 카드용) — Supabase 스키마
-- 흐름: 유저가 10장 단위 입고 신청 → 실물 발송 → 운영자 검수(일치/등급 하향/불일치/누락)
--       → 보관함 등록 → 판매 등록 → 다른 유저가 포인트로 구매(실물 이동 없이 소유권만 이동)
--       → 원할 때 출고 요청.
-- 원칙: 테이블은 직접 쓰지 못한다(RLS + 권한 회수). 모든 변경은 검증이 들어간 함수(RPC)로만.
-- 돈: MVP는 '포인트'. 운영자가 입금 확인 후 충전. (실결제·정산은 PG 에스크로 연동 단계에서)
-- Supabase SQL Editor에 이 파일 전체를 붙여 넣고 실행하면 된다.
-- =====================================================================
create extension if not exists pgcrypto;

-- ---------- 설정값 ----------
create or replace function public.cfg_fee_rate()      returns numeric language sql immutable as $$ select 0.05 $$;   -- 판매 수수료 5%
create or replace function public.cfg_max_price()     returns int     language sql immutable as $$ select 100000 $$; -- 중저가 상한 ₩100,000
create or replace function public.cfg_batch_size()    returns int     language sql immutable as $$ select 10 $$;     -- 배치당 최대 장수
create or replace function public.cfg_withdraw_fee()  returns int     language sql immutable as $$ select 3000 $$;   -- 출고 배송비(1회)

-- ---------- 테이블 ----------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  nickname    text not null default '',
  role        text not null default 'user' check (role in ('user', 'admin')),
  balance     bigint not null default 0 check (balance >= 0),
  trust       int not null default 100,
  created_at  timestamptz not null default now()
);

create table if not exists public.batches (
  id          uuid primary key default gen_random_uuid(),
  code        text unique not null default ('B' || to_char(now(), 'YYMMDD') || '-' || upper(substr(md5(random()::text), 1, 5))),
  owner       uuid not null references public.profiles(id),
  status      text not null default 'draft' check (status in ('draft', 'shipped', 'received', 'done')),
  tracking    text,
  created_at  timestamptz not null default now(),
  shipped_at  timestamptz,
  done_at     timestamptz
);

create table if not exists public.batch_items (
  id            uuid primary key default gen_random_uuid(),
  batch_id      uuid not null references public.batches(id) on delete cascade,
  seq           int not null,                        -- 슬리브에 넣는 순서(1~10)
  owner         uuid not null references public.profiles(id),
  card_id       text not null,                       -- TCGdex 카드 id (예: sv03.5-199)
  name          text not null,
  set_name      text,
  number        text,
  image         text,
  market_krw    int,
  user_grade    text not null check (user_grade in ('S', 'A', 'B', 'C')),
  user_finger   jsonb,                               -- 유저 스캔 센터링 지문(선택)
  status        text not null default 'pending' check (status in ('pending', 'matched', 'downgraded', 'mismatch', 'missing')),
  intake_grade  text check (intake_grade in ('S', 'A', 'B', 'C')),
  note          text,
  checked_at    timestamptz,
  unique (batch_id, seq)
);

create table if not exists public.vault_items (
  id             uuid primary key default gen_random_uuid(),
  owner          uuid not null references public.profiles(id),
  card_id        text not null,
  name           text not null,
  set_name       text,
  number         text,
  image          text,
  grade          text not null check (grade in ('S', 'A', 'B', 'C')),
  status         text not null default 'held' check (status in ('held', 'listed', 'withdraw_requested', 'shipped_out')),
  batch_item_id  uuid references public.batch_items(id),
  created_at     timestamptz not null default now()
);

create table if not exists public.listings (
  id             uuid primary key default gen_random_uuid(),
  vault_item_id  uuid not null references public.vault_items(id),
  seller         uuid not null references public.profiles(id),
  price          int not null,
  status         text not null default 'active' check (status in ('active', 'sold', 'cancelled')),
  created_at     timestamptz not null default now(),
  closed_at      timestamptz
);
create unique index if not exists one_active_listing on public.listings(vault_item_id) where status = 'active';

create table if not exists public.trades (
  id             uuid primary key default gen_random_uuid(),
  listing_id     uuid not null references public.listings(id),
  vault_item_id  uuid not null references public.vault_items(id),
  seller         uuid not null references public.profiles(id),
  buyer          uuid not null references public.profiles(id),
  price          int not null,
  fee            int not null,
  created_at     timestamptz not null default now()
);

create table if not exists public.ledger (
  id          bigserial primary key,
  user_id     uuid not null references public.profiles(id),
  amount      bigint not null,                        -- +입금 / -출금
  kind        text not null check (kind in ('topup', 'purchase', 'sale', 'fee', 'withdraw_fee', 'cashout', 'adjust')),
  ref         uuid,
  memo        text,
  created_at  timestamptz not null default now()
);

create table if not exists public.withdrawals (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null references public.profiles(id),
  items       uuid[] not null,
  address     text not null,
  status      text not null default 'requested' check (status in ('requested', 'shipped')),
  created_at  timestamptz not null default now(),
  shipped_at  timestamptz
);

-- ---------- 보안: 테이블 직접 접근 차단, 함수로만 ----------
alter table public.profiles     enable row level security;
alter table public.batches      enable row level security;
alter table public.batch_items  enable row level security;
alter table public.vault_items  enable row level security;
alter table public.listings     enable row level security;
alter table public.trades       enable row level security;
alter table public.ledger       enable row level security;
alter table public.withdrawals  enable row level security;
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

-- 가입하면 프로필 자동 생성
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, nickname) values (new.id, coalesce(split_part(new.email, '@', 1), ''))
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- ---------- 공통 ----------
create or replace function public._me() returns uuid language plpgsql stable security definer set search_path = public as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception '로그인이 필요해요' using errcode = '28000'; end if;
  return u;
end $$;
create or replace function public._is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
$$;
create or replace function public._need_admin() returns void language plpgsql stable security definer set search_path = public as $$
begin if not public._is_admin() then raise exception '운영자만 할 수 있어요' using errcode = '42501'; end if; end $$;

-- ---------- 읽기 ----------
create or replace function public.me() returns json language sql stable security definer set search_path = public as $$
  select json_build_object('id', p.id, 'nickname', p.nickname, 'role', p.role, 'balance', p.balance, 'trust', p.trust,
    'fee_rate', public.cfg_fee_rate(), 'max_price', public.cfg_max_price(), 'batch_size', public.cfg_batch_size(), 'withdraw_fee', public.cfg_withdraw_fee())
  from public.profiles p where p.id = public._me()
$$;

create or replace function public.set_nickname(p_nickname text) returns void language plpgsql security definer set search_path = public as $$
begin
  if length(trim(p_nickname)) not between 2 and 20 then raise exception '닉네임은 2~20자예요'; end if;
  update public.profiles set nickname = trim(p_nickname) where id = public._me();
end $$;

-- 마켓: 로그인 없이도 볼 수 있음. 판매자는 닉네임만 노출.
create or replace function public.market(p_q text default null, p_limit int default 100) returns json
language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(r order by r.created_at desc), '[]'::json) from (
    select l.id, l.price, l.created_at, v.card_id, v.name, v.set_name, v.number, v.image, v.grade,
           p.nickname as seller_name, (l.seller = auth.uid()) as mine
    from public.listings l join public.vault_items v on v.id = l.vault_item_id join public.profiles p on p.id = l.seller
    where l.status = 'active' and (p_q is null or p_q = '' or v.name ilike '%' || p_q || '%' or v.set_name ilike '%' || p_q || '%')
    order by l.created_at desc limit least(greatest(p_limit, 1), 200)
  ) r
$$;

create or replace function public.my_vault() returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(r order by r.created_at desc), '[]'::json) from (
    select v.*, l.id as listing_id, l.price
    from public.vault_items v left join public.listings l on l.vault_item_id = v.id and l.status = 'active'
    where v.owner = public._me() and v.status <> 'shipped_out'
  ) r
$$;

create or replace function public.my_batches() returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(b order by b.created_at desc), '[]'::json) from (
    select b.*, (select coalesce(json_agg(i order by i.seq), '[]'::json) from public.batch_items i where i.batch_id = b.id) as items
    from public.batches b where b.owner = public._me()
  ) b
$$;

create or replace function public.my_ledger() returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(r order by r.id desc), '[]'::json) from (
    select * from public.ledger where user_id = public._me() order by id desc limit 200
  ) r
$$;

-- ---------- 입고 신청 ----------
create or replace function public.open_batch() returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); b public.batches;
begin
  select * into b from public.batches where owner = u and status = 'draft' limit 1;
  if not found then insert into public.batches(owner) values (u) returning * into b; end if;
  return row_to_json(b);
end $$;

create or replace function public.add_batch_item(p_batch uuid, p_card_id text, p_name text, p_set text, p_number text, p_image text,
                                                 p_market int, p_grade text, p_finger jsonb default null) returns json
language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); b public.batches; n int; it public.batch_items;
begin
  select * into b from public.batches where id = p_batch for update;
  if not found or b.owner <> u then raise exception '내 입고 신청이 아니에요'; end if;
  if b.status <> 'draft' then raise exception '이미 발송한 배치예요'; end if;
  select count(*) into n from public.batch_items where batch_id = p_batch;
  if n >= public.cfg_batch_size() then raise exception '한 배치는 최대 %장이에요', public.cfg_batch_size(); end if;
  if p_market is not null and p_market > public.cfg_max_price() then
    raise exception '시세 ₩% 이상 카드는 PSA 등 그레이딩 기관을 이용해 주세요', to_char(public.cfg_max_price(), 'FM999,999,999'); end if;
  if coalesce(trim(p_card_id), '') = '' or coalesce(trim(p_name), '') = '' then raise exception '카드 정보가 비었어요'; end if;
  insert into public.batch_items(batch_id, seq, owner, card_id, name, set_name, number, image, market_krw, user_grade, user_finger)
  values (p_batch, n + 1, u, p_card_id, p_name, p_set, p_number, p_image, p_market, p_grade, p_finger) returning * into it;
  return row_to_json(it);
end $$;

create or replace function public.remove_batch_item(p_item uuid) returns void language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); it public.batch_items; b public.batches;
begin
  select * into it from public.batch_items where id = p_item;
  if not found or it.owner <> u then raise exception '내 카드가 아니에요'; end if;
  select * into b from public.batches where id = it.batch_id for update;
  if b.status <> 'draft' then raise exception '이미 발송한 배치예요'; end if;
  delete from public.batch_items where id = p_item;
  -- 슬리브 순서 다시 매기기
  update public.batch_items t set seq = s.rn from (
    select id, row_number() over (order by seq) + 1000 as rn from public.batch_items where batch_id = b.id) s where t.id = s.id;
  update public.batch_items set seq = seq - 1000 where batch_id = b.id;
end $$;

create or replace function public.submit_batch(p_batch uuid, p_tracking text) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); b public.batches; n int;
begin
  select * into b from public.batches where id = p_batch for update;
  if not found or b.owner <> u then raise exception '내 입고 신청이 아니에요'; end if;
  if b.status <> 'draft' then raise exception '이미 발송한 배치예요'; end if;
  select count(*) into n from public.batch_items where batch_id = p_batch;
  if n = 0 then raise exception '카드를 1장 이상 담아주세요'; end if;
  update public.batches set status = 'shipped', tracking = nullif(trim(p_tracking), ''), shipped_at = now() where id = p_batch returning * into b;
  return row_to_json(b);
end $$;

-- ---------- 운영자: 입고 검수 ----------
create or replace function public.admin_queue() returns json language plpgsql stable security definer set search_path = public as $$
begin
  perform public._need_admin();
  return (select coalesce(json_agg(b order by b.shipped_at), '[]'::json) from (
    select b.*, p.nickname as owner_name, p.trust,
           (select coalesce(json_agg(i order by i.seq), '[]'::json) from public.batch_items i where i.batch_id = b.id) as items
    from public.batches b join public.profiles p on p.id = b.owner where b.status in ('shipped', 'received')) b);
end $$;

-- p_result: matched(일치) · downgraded(등급 하향, p_grade 필수) · mismatch(다른 카드/바꿔치기 의심) · missing(누락)
create or replace function public.admin_check_item(p_item uuid, p_result text, p_grade text default null, p_note text default null) returns json
language plpgsql security definer set search_path = public as $$
declare it public.batch_items; b public.batches; g text; v public.vault_items; left_n int;
begin
  perform public._need_admin();
  select * into it from public.batch_items where id = p_item for update;
  if not found then raise exception '없는 카드예요'; end if;
  if it.status <> 'pending' then raise exception '이미 검수한 카드예요'; end if;
  select * into b from public.batches where id = it.batch_id for update;
  if b.status not in ('shipped', 'received') then raise exception '아직 발송되지 않은 배치예요'; end if;
  if p_result not in ('matched', 'downgraded', 'mismatch', 'missing') then raise exception '검수 결과가 올바르지 않아요'; end if;
  g := case when p_result = 'matched' then coalesce(p_grade, it.user_grade) when p_result = 'downgraded' then p_grade end;
  -- 등급 순서 S > A > B > C (문자열 비교 금지: 'A' < 'S'라서 틀림)
  if p_result = 'downgraded' and (p_grade is null or position(p_grade in 'SABC') <= position(it.user_grade in 'SABC')) then raise exception '하향 등급은 신청 등급보다 낮아야 해요'; end if;
  update public.batch_items set status = p_result, intake_grade = g, note = p_note, checked_at = now() where id = p_item;
  if p_result in ('matched', 'downgraded') then
    insert into public.vault_items(owner, card_id, name, set_name, number, image, grade, batch_item_id)
    values (it.owner, it.card_id, it.name, it.set_name, it.number, it.image, g, it.id) returning * into v;
  elsif p_result = 'mismatch' then
    update public.profiles set trust = trust - 10 where id = it.owner;
  end if;
  select count(*) into left_n from public.batch_items where batch_id = b.id and status = 'pending';
  update public.batches set status = case when left_n = 0 then 'done' else 'received' end,
                            done_at = case when left_n = 0 then now() end where id = b.id;
  return json_build_object('item', p_item, 'result', p_result, 'grade', g, 'vault_item', v.id, 'pending_left', left_n);
end $$;

-- ---------- 판매·구매 ----------
create or replace function public.list_item(p_vault uuid, p_price int) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); v public.vault_items; l public.listings;
begin
  select * into v from public.vault_items where id = p_vault for update;
  if not found or v.owner <> u then raise exception '내 보관함 카드가 아니에요'; end if;
  if v.status <> 'held' then raise exception '지금은 판매 등록할 수 없는 상태예요'; end if;
  if p_price < 100 or p_price > public.cfg_max_price() then raise exception '가격은 ₩100 ~ ₩% 사이로 정해주세요', to_char(public.cfg_max_price(), 'FM999,999,999'); end if;
  insert into public.listings(vault_item_id, seller, price) values (p_vault, u, p_price) returning * into l;
  update public.vault_items set status = 'listed' where id = p_vault;
  return row_to_json(l);
end $$;

create or replace function public.cancel_listing(p_listing uuid) returns void language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); l public.listings;
begin
  select * into l from public.listings where id = p_listing for update;
  if not found or l.seller <> u then raise exception '내 판매글이 아니에요'; end if;
  if l.status <> 'active' then raise exception '이미 끝난 판매글이에요'; end if;
  update public.listings set status = 'cancelled', closed_at = now() where id = p_listing;
  update public.vault_items set status = 'held' where id = l.vault_item_id;
end $$;

-- 구매: 잔액 확인 → 포인트 이동(수수료 차감) → 소유권 이동. 한 트랜잭션에서 행 잠금으로 처리.
create or replace function public.buy_listing(p_listing uuid) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); l public.listings; bal bigint; fee int; t public.trades;
begin
  select * into l from public.listings where id = p_listing for update;
  if not found or l.status <> 'active' then raise exception '이미 팔렸거나 없는 판매글이에요'; end if;
  if l.seller = u then raise exception '내 카드는 살 수 없어요'; end if;
  select balance into bal from public.profiles where id = u for update;
  if bal < l.price then raise exception '포인트가 부족해요 (필요 ₩%, 보유 ₩%)', to_char(l.price, 'FM999,999,999,999'), to_char(bal, 'FM999,999,999,999'); end if;
  perform 1 from public.profiles where id = l.seller for update;
  fee := ceil(l.price * public.cfg_fee_rate());
  update public.profiles set balance = balance - l.price where id = u;
  update public.profiles set balance = balance + l.price - fee where id = l.seller;
  update public.listings set status = 'sold', closed_at = now() where id = l.id;
  update public.vault_items set owner = u, status = 'held' where id = l.vault_item_id;
  insert into public.trades(listing_id, vault_item_id, seller, buyer, price, fee) values (l.id, l.vault_item_id, l.seller, u, l.price, fee) returning * into t;
  insert into public.ledger(user_id, amount, kind, ref, memo) values
    (u, -l.price, 'purchase', t.id, '카드 구매'),
    (l.seller, l.price, 'sale', t.id, '카드 판매'),
    (l.seller, -fee, 'fee', t.id, '판매 수수료');
  return row_to_json(t);
end $$;

-- ---------- 출고 ----------
create or replace function public.request_withdraw(p_items uuid[], p_address text) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); n int; bal bigint; w public.withdrawals; fee int := public.cfg_withdraw_fee();
begin
  if coalesce(array_length(p_items, 1), 0) = 0 then raise exception '출고할 카드를 골라주세요'; end if;
  if length(coalesce(trim(p_address), '')) < 5 then raise exception '받을 주소를 적어주세요'; end if;
  select count(*) into n from public.vault_items where id = any(p_items) and owner = u and status = 'held';
  if n <> array_length(p_items, 1) then raise exception '보관 중(판매 등록 안 된) 내 카드만 출고할 수 있어요'; end if;
  select balance into bal from public.profiles where id = u for update;
  if bal < fee then raise exception '배송비 ₩% 포인트가 부족해요', to_char(fee, 'FM999,999,999'); end if;
  update public.profiles set balance = balance - fee where id = u;
  update public.vault_items set status = 'withdraw_requested' where id = any(p_items);
  insert into public.withdrawals(owner, items, address) values (u, p_items, trim(p_address)) returning * into w;
  insert into public.ledger(user_id, amount, kind, ref, memo) values (u, -fee, 'withdraw_fee', w.id, '출고 배송비');
  return row_to_json(w);
end $$;

-- ---------- 운영자: 포인트·출고·회원 ----------
create or replace function public.admin_find_user(p_email text) returns json language plpgsql stable security definer set search_path = public as $$
begin
  perform public._need_admin();
  return (select json_build_object('id', p.id, 'email', a.email, 'nickname', p.nickname, 'balance', p.balance, 'trust', p.trust)
          from auth.users a join public.profiles p on p.id = a.id where lower(a.email) = lower(trim(p_email)));
end $$;

create or replace function public.admin_topup(p_user uuid, p_amount bigint, p_memo text default null) returns json language plpgsql security definer set search_path = public as $$
declare bal bigint;
begin
  perform public._need_admin();
  if p_amount = 0 or abs(p_amount) > 10000000 then raise exception '금액을 확인해 주세요'; end if;
  update public.profiles set balance = balance + p_amount where id = p_user returning balance into bal;
  if not found then raise exception '없는 회원이에요'; end if;
  insert into public.ledger(user_id, amount, kind, memo) values (p_user, p_amount, case when p_amount > 0 then 'topup' else 'cashout' end, p_memo);
  return json_build_object('user', p_user, 'balance', bal);
end $$;

create or replace function public.admin_withdrawals() returns json language plpgsql stable security definer set search_path = public as $$
begin
  perform public._need_admin();
  return (select coalesce(json_agg(r order by r.created_at), '[]'::json) from (
    select w.*, p.nickname as owner_name,
      (select json_agg(json_build_object('id', v.id, 'name', v.name, 'set_name', v.set_name, 'number', v.number, 'grade', v.grade)) from public.vault_items v where v.id = any(w.items)) as cards
    from public.withdrawals w join public.profiles p on p.id = w.owner where w.status = 'requested') r);
end $$;

create or replace function public.admin_ship_withdrawal(p_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare w public.withdrawals;
begin
  perform public._need_admin();
  select * into w from public.withdrawals where id = p_id for update;
  if not found or w.status <> 'requested' then raise exception '처리할 출고 요청이 아니에요'; end if;
  update public.withdrawals set status = 'shipped', shipped_at = now() where id = p_id;
  update public.vault_items set status = 'shipped_out' where id = any(w.items);
end $$;

-- ---------- 함수 실행 권한 ----------
revoke execute on all functions in schema public from public, anon;
grant execute on function public.market(text, int) to anon, authenticated;
grant execute on function
  public.me(), public.set_nickname(text), public.my_vault(), public.my_batches(), public.my_ledger(),
  public.open_batch(), public.add_batch_item(uuid, text, text, text, text, text, int, text, jsonb), public.remove_batch_item(uuid), public.submit_batch(uuid, text),
  public.list_item(uuid, int), public.cancel_listing(uuid), public.buy_listing(uuid), public.request_withdraw(uuid[], text),
  public.admin_queue(), public.admin_check_item(uuid, text, text, text), public.admin_find_user(text), public.admin_topup(uuid, bigint, text),
  public.admin_withdrawals(), public.admin_ship_withdrawal(uuid)
to authenticated;
