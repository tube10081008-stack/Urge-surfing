-- =====================================================================
-- 카드 보관·거래 MVP (중저가 카드용) — Supabase 스키마
-- 흐름: 유저가 10장 단위 입고 신청 → 실물 발송 → 운영자 검수(일치/등급 하향/불일치/누락)
--       → 보관함 등록 → 판매 등록 → 다른 유저가 포인트로 구매(실물 이동 없이 소유권만 이동)
--       → 원할 때 출고 요청.
-- v2: 시간제 경매(스나이핑 방지 연장·가격 확인 입찰·포인트 예치), 가격 제안, 찜 알림, 알림함,
--     판매자 신뢰 지표·카드 거래 이력 공개, 월 지출 한도(올리면 24시간 뒤 적용)
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

-- ---------- v2 테이블·컬럼 (기존 설치 업그레이드도 되도록 add column if not exists) ----------
-- held: 입찰·가격 제안으로 묶인 포인트. balance는 '쓸 수 있는' 포인트. 원장 합계 = balance + held.
alter table public.profiles add column if not exists held bigint not null default 0;
alter table public.profiles drop constraint if exists profiles_held_check;
alter table public.profiles add constraint profiles_held_check check (held >= 0);
alter table public.profiles add column if not exists monthly_limit int;          -- 월 지출 한도(null = 없음)
alter table public.profiles add column if not exists limit_next int;             -- 예약된 새 한도
alter table public.profiles add column if not exists limit_next_at timestamptz;  -- 새 한도 적용 시각(올릴 때 24시간 뒤)

alter table public.listings add column if not exists kind text not null default 'fixed';
alter table public.listings drop constraint if exists listings_kind_check;
alter table public.listings add constraint listings_kind_check check (kind in ('fixed', 'auction'));
alter table public.listings add column if not exists ends_at timestamptz;
alter table public.listings add column if not exists top_bid int;
alter table public.listings add column if not exists top_bidder uuid references public.profiles(id);
alter table public.listings add column if not exists bid_count int not null default 0;
alter table public.listings drop constraint if exists listings_status_check;
alter table public.listings add constraint listings_status_check check (status in ('active', 'sold', 'cancelled', 'expired'));

create table if not exists public.bids (
  id          bigserial primary key,
  listing_id  uuid not null references public.listings(id),
  bidder      uuid not null references public.profiles(id),
  amount      int not null,
  created_at  timestamptz not null default now()
);
create index if not exists bids_listing on public.bids(listing_id, id desc);

create table if not exists public.offers (
  id          uuid primary key default gen_random_uuid(),
  listing_id  uuid not null references public.listings(id),
  buyer       uuid not null references public.profiles(id),
  amount      int not null,
  status      text not null default 'active' check (status in ('active', 'accepted', 'declined', 'cancelled', 'expired')),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '48 hours',
  closed_at   timestamptz
);
create unique index if not exists one_active_offer on public.offers(listing_id, buyer) where status = 'active';

create table if not exists public.wishes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  query       text not null,
  created_at  timestamptz not null default now()
);
create unique index if not exists wish_unique on public.wishes(user_id, lower(query));

create table if not exists public.notifications (
  id          bigserial primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        text not null,
  title       text not null,
  body        text,
  ref         uuid,
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists notif_user on public.notifications(user_id, id desc);

-- ---------- 보안: 테이블 직접 접근 차단, 함수로만 ----------
alter table public.profiles     enable row level security;
alter table public.batches      enable row level security;
alter table public.batch_items  enable row level security;
alter table public.vault_items  enable row level security;
alter table public.listings     enable row level security;
alter table public.trades       enable row level security;
alter table public.ledger       enable row level security;
alter table public.withdrawals  enable row level security;
alter table public.bids         enable row level security;
alter table public.offers       enable row level security;
alter table public.wishes       enable row level security;
alter table public.notifications enable row level security;
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

create or replace function public._won(n bigint) returns text language sql immutable as $$ select '₩' || to_char(n, 'FM999,999,999,999') $$;
create or replace function public._notify(p_user uuid, p_kind text, p_title text, p_body text default null, p_ref uuid default null) returns void
language sql security definer set search_path = public as $$
  insert into public.notifications(user_id, kind, title, body, ref) values (p_user, p_kind, p_title, p_body, p_ref)
$$;
-- 경매 최소 증액 단위
create or replace function public._step(p int) returns int language sql immutable as $$
  select case when p < 10000 then 500 when p < 50000 then 1000 else 2000 end
$$;
-- 지금 적용 중인 월 지출 한도 (예약된 한도가 적용 시각을 지났으면 그것)
create or replace function public._limit_of(p public.profiles) returns int language sql stable as $$
  select case when p.limit_next_at is not null and p.limit_next_at <= now() then p.limit_next else p.monthly_limit end
$$;
-- 이번 달 지출 = 이번 달 구매액 + 지금 묶여 있는 포인트(입찰·제안)
create or replace function public._spent_month(p_user uuid) returns bigint language sql stable security definer set search_path = public as $$
  select coalesce((select -sum(amount) from public.ledger where user_id = p_user and kind = 'purchase' and created_at >= date_trunc('month', now())), 0)
       + (select held from public.profiles where id = p_user)
$$;
-- 과소비 방지: 한도를 넘는 구매·입찰·제안은 막는다
create or replace function public._check_spend(p_user uuid, p_add bigint) returns void language plpgsql stable security definer set search_path = public as $$
declare p public.profiles; lim int; spent bigint;
begin
  select * into p from public.profiles where id = p_user;
  lim := public._limit_of(p);
  if lim is null then return; end if;
  spent := public._spent_month(p_user);
  if spent + p_add > lim then
    raise exception '이번 달 지출 한도 %를 넘어요 (이미 %, 이번 %). 한도는 지갑에서 바꿀 수 있어요', public._won(lim), public._won(spent), public._won(p_add);
  end if;
end $$;
-- 포인트 묶기/풀기 (입찰·제안 예치)
create or replace function public._hold(p_user uuid, p_amount bigint) returns void language plpgsql security definer set search_path = public as $$
declare bal bigint;
begin
  select balance into bal from public.profiles where id = p_user for update;
  if bal < p_amount then raise exception '포인트가 부족해요 (필요 %, 보유 %)', public._won(p_amount), public._won(bal); end if;
  update public.profiles set balance = balance - p_amount, held = held + p_amount where id = p_user;
end $$;
create or replace function public._release(p_user uuid, p_amount bigint) returns void language sql security definer set search_path = public as $$
  update public.profiles set balance = balance + p_amount, held = held - p_amount where id = p_user
$$;
-- 거래 체결 공통: 구매자 돈(p_from_held면 묶인 포인트에서) → 판매자(수수료 차감), 소유권 이동, 원장
create or replace function public._settle_trade(p_listing public.listings, p_buyer uuid, p_price int, p_from_held boolean) returns public.trades
language plpgsql security definer set search_path = public as $$
declare fee int := ceil(p_price * public.cfg_fee_rate()); t public.trades; bal bigint;
begin
  perform 1 from public.profiles where id in (p_buyer, p_listing.seller) order by id for update;
  if p_from_held then
    update public.profiles set held = held - p_price where id = p_buyer;
  else
    select balance into bal from public.profiles where id = p_buyer;
    if bal < p_price then raise exception '포인트가 부족해요 (필요 %, 보유 %)', public._won(p_price), public._won(bal); end if;
    update public.profiles set balance = balance - p_price where id = p_buyer;
  end if;
  update public.profiles set balance = balance + p_price - fee where id = p_listing.seller;
  update public.listings set status = 'sold', closed_at = now() where id = p_listing.id;
  update public.vault_items set owner = p_buyer, status = 'held' where id = p_listing.vault_item_id;
  insert into public.trades(listing_id, vault_item_id, seller, buyer, price, fee)
  values (p_listing.id, p_listing.vault_item_id, p_listing.seller, p_buyer, p_price, fee) returning * into t;
  insert into public.ledger(user_id, amount, kind, ref, memo) values
    (p_buyer, -p_price, 'purchase', t.id, '카드 구매'),
    (p_listing.seller, p_price, 'sale', t.id, '카드 판매'),
    (p_listing.seller, -fee, 'fee', t.id, '판매 수수료');
  return t;
end $$;
-- 판매글에 걸린 다른 제안을 모두 돌려준다
create or replace function public._close_offers(p_listing uuid, p_except uuid, p_status text, p_msg text) returns void
language plpgsql security definer set search_path = public as $$
declare o public.offers;
begin
  for o in select * from public.offers where listing_id = p_listing and status = 'active' and id is distinct from p_except for update loop
    perform public._release(o.buyer, o.amount);
    update public.offers set status = p_status, closed_at = now() where id = o.id;
    perform public._notify(o.buyer, 'offer_closed', p_msg, public._won(o.amount) || ' 포인트를 돌려드렸어요', p_listing);
  end loop;
end $$;
-- 새 판매글이 찜과 맞으면 알림
create or replace function public._notify_wishes(p_listing uuid) returns void language plpgsql security definer set search_path = public as $$
declare l public.listings; v public.vault_items;
begin
  select * into l from public.listings where id = p_listing;
  select * into v from public.vault_items where id = l.vault_item_id;
  insert into public.notifications(user_id, kind, title, body, ref)
  select distinct w.user_id, 'wish', '찜한 카드가 올라왔어요: ' || v.name,
         coalesce(v.set_name, '') || ' · 등급 ' || v.grade || ' · ' || case when l.kind = 'auction' then '경매 시작 ' else '' end || public._won(l.price), l.id
  from public.wishes w where w.user_id <> l.seller and (v.name ilike '%' || w.query || '%' or v.card_id = w.query);
end $$;
-- 경매 마감 처리 (낙찰 또는 유찰)
create or replace function public._settle_auction(p_listing uuid) returns void language plpgsql security definer set search_path = public as $$
declare l public.listings; v public.vault_items; t public.trades;
begin
  select * into l from public.listings where id = p_listing for update;
  if not found or l.kind <> 'auction' or l.status <> 'active' or l.ends_at > now() then return; end if;
  select * into v from public.vault_items where id = l.vault_item_id;
  if l.top_bidder is null then
    update public.listings set status = 'expired', closed_at = now() where id = l.id;
    update public.vault_items set status = 'held' where id = l.vault_item_id;
    perform public._notify(l.seller, 'auction_expired', '경매가 유찰됐어요: ' || v.name, '입찰이 없어서 보관함으로 돌아왔어요', l.id);
  else
    t := public._settle_trade(l, l.top_bidder, l.top_bid, true);
    perform public._notify(l.top_bidder, 'auction_won', '낙찰! ' || v.name, public._won(l.top_bid) || '에 내 보관함으로 들어왔어요', l.id);
    perform public._notify(l.seller, 'sold', '경매로 팔렸어요: ' || v.name, public._won(l.top_bid) || ' (수수료 ' || public._won(t.fee) || ' 제외 후 입금)', l.id);
  end if;
end $$;
-- 시간 지난 것 정리: 마감된 경매, 만료된 제안. 마켓을 열 때마다 호출된다(크론 없이도 동작).
create or replace function public.sweep() returns int language plpgsql security definer set search_path = public as $$
declare r record; n int := 0;
begin
  for r in select id from public.listings where kind = 'auction' and status = 'active' and ends_at <= now() for update skip locked loop
    perform public._settle_auction(r.id); n := n + 1;
  end loop;
  for r in select * from public.offers where status = 'active' and expires_at <= now() for update skip locked loop
    perform public._release(r.buyer, r.amount);
    update public.offers set status = 'expired', closed_at = now() where id = r.id;
    perform public._notify(r.buyer, 'offer_closed', '가격 제안이 만료됐어요', public._won(r.amount) || ' 포인트를 돌려드렸어요', r.listing_id);
    n := n + 1;
  end loop;
  return n;
end $$;

-- ---------- 읽기 ----------
create or replace function public.me() returns json language sql stable security definer set search_path = public as $$
  select json_build_object('id', p.id, 'nickname', p.nickname, 'role', p.role, 'balance', p.balance, 'held', p.held, 'trust', p.trust,
    'fee_rate', public.cfg_fee_rate(), 'max_price', public.cfg_max_price(), 'batch_size', public.cfg_batch_size(), 'withdraw_fee', public.cfg_withdraw_fee(),
    'monthly_limit', public._limit_of(p), 'spent_month', public._spent_month(p.id),
    'limit_next', case when p.limit_next_at > now() then p.limit_next end, 'limit_next_at', case when p.limit_next_at > now() then p.limit_next_at end,
    'limit_next_pending', p.limit_next_at > now(),
    'unread', (select count(*) from public.notifications n where n.user_id = p.id and not n.read))
  from public.profiles p where p.id = public._me()
$$;

create or replace function public.set_nickname(p_nickname text) returns void language plpgsql security definer set search_path = public as $$
begin
  if length(trim(p_nickname)) not between 2 and 20 then raise exception '닉네임은 2~20자예요'; end if;
  update public.profiles set nickname = trim(p_nickname) where id = public._me();
end $$;

-- 마켓: 로그인 없이도 볼 수 있음. 판매자는 닉네임과 신뢰 지표만 노출. 열 때마다 마감된 경매부터 정리.
-- p_kind: null(전체) · 'fixed'(즉시 구매) · 'auction'(경매)
create or replace function public._seller_stats(p_user uuid) returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'sales', (select count(*) from public.trades where seller = p_user),
    'checked', (select count(*) from public.batch_items where owner = p_user and status <> 'pending'),
    'matched', (select count(*) from public.batch_items where owner = p_user and status = 'matched'),
    'trust', (select trust from public.profiles where id = p_user),
    'since', (select created_at from public.profiles where id = p_user))
$$;
create or replace function public.market(p_q text default null, p_limit int default 100, p_kind text default null) returns json
language plpgsql security definer set search_path = public as $$
begin
  perform public.sweep();
  return (select coalesce(json_agg(r order by r.sort_key), '[]'::json) from (
    select l.id, l.kind, l.price, l.created_at, l.ends_at, l.top_bid, l.bid_count,
           coalesce(l.top_bid + public._step(l.top_bid), l.price) as next_min,
           v.card_id, v.name, v.set_name, v.number, v.image, v.grade,
           p.nickname as seller_name, public._seller_stats(l.seller) as seller,
           (l.seller = auth.uid()) as mine, (l.top_bidder = auth.uid()) as my_top,
           (select o.amount from public.offers o where o.listing_id = l.id and o.buyer = auth.uid() and o.status = 'active') as my_offer,
           (select t.price from public.trades t join public.vault_items tv on tv.id = t.vault_item_id
             where tv.card_id = v.card_id and tv.grade = v.grade order by t.created_at desc limit 1) as last_price,
           case when l.kind = 'auction' then extract(epoch from l.ends_at) else -extract(epoch from l.created_at) end as sort_key
    from public.listings l join public.vault_items v on v.id = l.vault_item_id join public.profiles p on p.id = l.seller
    where l.status = 'active' and (p_kind is null or l.kind = p_kind)
      and (p_q is null or p_q = '' or v.name ilike '%' || p_q || '%' or v.set_name ilike '%' || p_q || '%')
    order by sort_key limit least(greatest(p_limit, 1), 200)
  ) r);
end $$;

-- 판매글 상세: 입찰 기록(닉네임 가림), 같은 카드 최근 거래가
create or replace function public.listing_detail(p_listing uuid) returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'bids', (select coalesce(json_agg(json_build_object('amount', b.amount, 'at', b.created_at, 'mine', b.bidder = auth.uid(),
                    'who', left(p.nickname, 1) || '**') order by b.id desc), '[]'::json)
             from (select * from public.bids where listing_id = l.id order by id desc limit 30) b join public.profiles p on p.id = b.bidder),
    'history', (select coalesce(json_agg(json_build_object('price', t.price, 'grade', tv.grade, 'at', t.created_at) order by t.created_at desc), '[]'::json)
                from (select t.* from public.trades t join public.vault_items x on x.id = t.vault_item_id where x.card_id = v.card_id order by t.created_at desc limit 10) t
                join public.vault_items tv on tv.id = t.vault_item_id),
    'offers', (select count(*) from public.offers where listing_id = l.id and status = 'active'))
  from public.listings l join public.vault_items v on v.id = l.vault_item_id where l.id = p_listing
$$;

create or replace function public.my_vault() returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(r order by r.created_at desc), '[]'::json) from (
    select v.*, l.id as listing_id, l.price, l.kind, l.ends_at, l.top_bid, l.bid_count,
      (select coalesce(json_agg(json_build_object('id', o.id, 'amount', o.amount, 'buyer', bp.nickname, 'expires_at', o.expires_at) order by o.amount desc), '[]'::json)
         from public.offers o join public.profiles bp on bp.id = o.buyer where o.listing_id = l.id and o.status = 'active') as offers
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
  if left_n = 0 then
    perform public._notify(b.owner, 'intake', '입고 검수가 끝났어요: ' || b.code,
      (select count(*) filter (where status in ('matched', 'downgraded')) || '장 보관함 등록 · ' || count(*) filter (where status in ('mismatch', 'missing')) || '장 미등록'
       from public.batch_items where batch_id = b.id), b.id);
  end if;
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
  perform public._notify_wishes(l.id);
  return row_to_json(l);
end $$;

create or replace function public.cancel_listing(p_listing uuid) returns void language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); l public.listings;
begin
  select * into l from public.listings where id = p_listing for update;
  if not found or l.seller <> u then raise exception '내 판매글이 아니에요'; end if;
  if l.status <> 'active' then raise exception '이미 끝난 판매글이에요'; end if;
  if l.kind = 'auction' and l.bid_count > 0 then raise exception '입찰이 들어온 경매는 취소할 수 없어요'; end if;
  update public.listings set status = 'cancelled', closed_at = now() where id = p_listing;
  update public.vault_items set status = 'held' where id = l.vault_item_id;
  perform public._close_offers(l.id, null, 'cancelled', '판매자가 판매를 취소해서 제안이 닫혔어요');
end $$;

-- 즉시 구매: 한도 확인 → 포인트 이동(수수료 차감) → 소유권 이동. 한 트랜잭션에서 행 잠금으로 처리.
-- p_expected: 화면에서 본 가격. 그 사이 바뀌었으면 거절(오구매 방지).
create or replace function public.buy_listing(p_listing uuid, p_expected int default null) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); l public.listings; t public.trades; v public.vault_items;
begin
  select * into l from public.listings where id = p_listing for update;
  if not found or l.status <> 'active' then raise exception '이미 팔렸거나 없는 판매글이에요'; end if;
  if l.kind <> 'fixed' then raise exception '경매 카드는 입찰로만 살 수 있어요'; end if;
  if l.seller = u then raise exception '내 카드는 살 수 없어요'; end if;
  if p_expected is not null and p_expected <> l.price then raise exception '그 사이 가격이 바뀌었어요 (지금 %). 다시 확인해 주세요', public._won(l.price); end if;
  perform public._check_spend(u, l.price);
  t := public._settle_trade(l, u, l.price, false);
  perform public._close_offers(l.id, null, 'cancelled', '다른 분이 먼저 사서 제안이 닫혔어요');
  select * into v from public.vault_items where id = l.vault_item_id;
  perform public._notify(l.seller, 'sold', '팔렸어요: ' || v.name, public._won(l.price) || ' (수수료 ' || public._won(t.fee) || ' 제외 후 입금)', l.id);
  return row_to_json(t);
end $$;

-- ---------- 경매 ----------
-- 시간제 경매: 6/24/72시간. 마감 5분 안에 입찰이 들어오면 5분 연장(막판 스나이핑 방지).
create or replace function public.start_auction(p_vault uuid, p_start int, p_hours int) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); v public.vault_items; l public.listings;
begin
  select * into v from public.vault_items where id = p_vault for update;
  if not found or v.owner <> u then raise exception '내 보관함 카드가 아니에요'; end if;
  if v.status <> 'held' then raise exception '지금은 판매 등록할 수 없는 상태예요'; end if;
  if p_start < 100 or p_start > public.cfg_max_price() then raise exception '시작가는 ₩100 ~ % 사이로 정해주세요', public._won(public.cfg_max_price()); end if;
  if p_hours not in (6, 24, 72) then raise exception '경매 기간은 6·24·72시간 중에서 골라주세요'; end if;
  insert into public.listings(vault_item_id, seller, price, kind, ends_at) values (p_vault, u, p_start, 'auction', now() + make_interval(hours => p_hours)) returning * into l;
  update public.vault_items set status = 'listed' where id = p_vault;
  perform public._notify_wishes(l.id);
  return row_to_json(l);
end $$;

-- 입찰: p_seen_top = 화면에서 본 현재가(입찰 없으면 null). 그 사이 바뀌었으면 거절(오입찰 방지).
-- 입찰액은 바로 묶이고(미입금 없음), 더 높은 입찰이 오면 자동으로 돌려준다. 입찰 취소는 없다.
create or replace function public.place_bid(p_listing uuid, p_amount int, p_seen_top int default null) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); l public.listings; v public.vault_items; need int; add bigint; prev uuid; prev_amt int;
begin
  select * into l from public.listings where id = p_listing for update;
  if not found or l.status <> 'active' or l.kind <> 'auction' then raise exception '진행 중인 경매가 아니에요'; end if;
  if l.ends_at <= now() then raise exception '경매가 끝났어요'; end if;
  if l.seller = u then raise exception '내 경매에는 입찰할 수 없어요'; end if;
  if p_seen_top is distinct from l.top_bid then raise exception '그 사이 입찰가가 바뀌었어요 (지금 %). 다시 확인해 주세요', public._won(coalesce(l.top_bid, l.price)); end if;
  need := coalesce(l.top_bid + public._step(l.top_bid), l.price);
  if p_amount < need then raise exception '최소 %부터 입찰할 수 있어요', public._won(need); end if;
  if p_amount > public.cfg_max_price() then raise exception '입찰은 %까지예요', public._won(public.cfg_max_price()); end if;
  prev := l.top_bidder; prev_amt := l.top_bid;
  add := case when prev = u then p_amount - prev_amt else p_amount end;
  perform public._check_spend(u, add);
  perform 1 from public.profiles where id in (u, prev) order by id for update;
  if prev is not null and prev <> u then perform public._release(prev, prev_amt); end if;
  perform public._hold(u, add);
  insert into public.bids(listing_id, bidder, amount) values (l.id, u, p_amount);
  update public.listings set top_bid = p_amount, top_bidder = u, bid_count = bid_count + 1,
    ends_at = greatest(ends_at, now() + interval '5 minutes') where id = l.id returning * into l;
  select * into v from public.vault_items where id = l.vault_item_id;
  if prev is not null and prev <> u then
    perform public._notify(prev, 'outbid', '더 높은 입찰이 들어왔어요: ' || v.name, '지금 ' || public._won(p_amount) || ' · 묶였던 ' || public._won(prev_amt) || '는 돌려드렸어요', l.id);
  end if;
  return json_build_object('top_bid', l.top_bid, 'ends_at', l.ends_at, 'bid_count', l.bid_count, 'next_min', l.top_bid + public._step(l.top_bid));
end $$;

-- ---------- 가격 제안 ----------
-- 즉시 구매 카드에 더 낮은 가격을 제안. 제안액은 바로 묶이고 48시간 뒤 자동 만료·반환.
create or replace function public.make_offer(p_listing uuid, p_amount int) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); l public.listings; v public.vault_items; o public.offers;
begin
  select * into l from public.listings where id = p_listing for update;
  if not found or l.status <> 'active' or l.kind <> 'fixed' then raise exception '가격 제안을 받을 수 없는 판매글이에요'; end if;
  if l.seller = u then raise exception '내 카드에는 제안할 수 없어요'; end if;
  if p_amount < 100 or p_amount >= l.price then raise exception '제안가는 ₩100 이상, 판매가(%)보다 낮게 적어주세요', public._won(l.price); end if;
  if exists (select 1 from public.offers where listing_id = l.id and buyer = u and status = 'active') then raise exception '이미 제안한 카드예요. 기존 제안을 취소하고 다시 해주세요'; end if;
  perform public._check_spend(u, p_amount);
  perform public._hold(u, p_amount);
  insert into public.offers(listing_id, buyer, amount) values (l.id, u, p_amount) returning * into o;
  select * into v from public.vault_items where id = l.vault_item_id;
  perform public._notify(l.seller, 'offer', '가격 제안이 왔어요: ' || v.name, public._won(p_amount) || ' (판매가 ' || public._won(l.price) || ') · 48시간 안에 수락하면 바로 팔려요', l.id);
  return row_to_json(o);
end $$;

create or replace function public.cancel_offer(p_offer uuid) returns void language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); o public.offers;
begin
  select * into o from public.offers where id = p_offer for update;
  if not found or o.buyer <> u then raise exception '내 제안이 아니에요'; end if;
  if o.status <> 'active' then raise exception '이미 끝난 제안이에요'; end if;
  perform public._release(u, o.amount);
  update public.offers set status = 'cancelled', closed_at = now() where id = o.id;
end $$;

create or replace function public.respond_offer(p_offer uuid, p_accept boolean) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); o public.offers; l public.listings; v public.vault_items; t public.trades;
begin
  select * into o from public.offers where id = p_offer;
  if not found then raise exception '없는 제안이에요'; end if;
  select * into l from public.listings where id = o.listing_id for update;
  if l.seller <> u then raise exception '내 판매글에 온 제안이 아니에요'; end if;
  select * into o from public.offers where id = p_offer for update;
  if o.status <> 'active' or o.expires_at <= now() then raise exception '이미 끝났거나 만료된 제안이에요'; end if;
  if l.status <> 'active' then raise exception '이미 끝난 판매글이에요'; end if;
  select * into v from public.vault_items where id = l.vault_item_id;
  if not p_accept then
    perform public._release(o.buyer, o.amount);
    update public.offers set status = 'declined', closed_at = now() where id = o.id;
    perform public._notify(o.buyer, 'offer_closed', '제안이 거절됐어요: ' || v.name, public._won(o.amount) || ' 포인트를 돌려드렸어요', l.id);
    return json_build_object('accepted', false);
  end if;
  update public.offers set status = 'accepted', closed_at = now() where id = o.id;
  t := public._settle_trade(l, o.buyer, o.amount, true);
  perform public._close_offers(l.id, o.id, 'cancelled', '다른 제안이 수락돼서 제안이 닫혔어요');
  perform public._notify(o.buyer, 'offer_accepted', '제안이 수락됐어요! ' || v.name, public._won(o.amount) || '에 내 보관함으로 들어왔어요', l.id);
  return json_build_object('accepted', true, 'trade', row_to_json(t));
end $$;

-- 내가 건 입찰·제안 (묶인 포인트 내역)
create or replace function public.my_activity() returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'offers', (select coalesce(json_agg(json_build_object('id', o.id, 'amount', o.amount, 'status', o.status, 'expires_at', o.expires_at,
                 'name', v.name, 'grade', v.grade, 'image', v.image, 'price', l.price) order by o.created_at desc), '[]'::json)
               from public.offers o join public.listings l on l.id = o.listing_id join public.vault_items v on v.id = l.vault_item_id
               where o.buyer = public._me() and (o.status = 'active' or o.closed_at > now() - interval '7 days')),
    'bids', (select coalesce(json_agg(json_build_object('listing', l.id, 'name', v.name, 'grade', v.grade, 'image', v.image, 'top_bid', l.top_bid,
                 'ends_at', l.ends_at, 'leading', l.top_bidder = public._me(), 'my_max', (select max(amount) from public.bids where listing_id = l.id and bidder = public._me())) order by l.ends_at), '[]'::json)
             from public.listings l join public.vault_items v on v.id = l.vault_item_id
             where l.status = 'active' and l.kind = 'auction' and exists (select 1 from public.bids b where b.listing_id = l.id and b.bidder = public._me())))
$$;

-- ---------- 찜 · 알림 ----------
create or replace function public.add_wish(p_query text) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); w public.wishes;
begin
  if length(coalesce(trim(p_query), '')) < 2 then raise exception '카드 이름을 2자 이상 적어주세요'; end if;
  if (select count(*) from public.wishes where user_id = u) >= 50 then raise exception '찜은 50개까지예요'; end if;
  insert into public.wishes(user_id, query) values (u, trim(p_query)) on conflict (user_id, lower(query)) do nothing returning * into w;
  if w.id is null then raise exception '이미 찜한 카드예요'; end if;
  return row_to_json(w);
end $$;
create or replace function public.remove_wish(p_id uuid) returns void language sql security definer set search_path = public as $$
  delete from public.wishes where id = p_id and user_id = public._me()
$$;
create or replace function public.my_wishes() returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(w order by w.created_at desc), '[]'::json) from public.wishes w where w.user_id = public._me()
$$;
create or replace function public.my_notifications(p_limit int default 50) returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(n order by n.id desc), '[]'::json) from (
    select * from public.notifications where user_id = public._me() order by id desc limit least(greatest(p_limit, 1), 200)) n
$$;
create or replace function public.read_notifications() returns void language sql security definer set search_path = public as $$
  update public.notifications set read = true where user_id = public._me() and not read
$$;

-- ---------- 과소비 방지: 월 지출 한도 ----------
-- 낮추기는 즉시, 올리기·없애기는 24시간 뒤 적용(충동적으로 한도를 푸는 것 방지).
create or replace function public.set_spend_limit(p_limit int) returns json language plpgsql security definer set search_path = public as $$
declare u uuid := public._me(); p public.profiles; cur int;
begin
  if p_limit is not null and p_limit < 0 then raise exception '한도는 0원 이상이에요'; end if;
  select * into p from public.profiles where id = u for update;
  cur := public._limit_of(p);
  if p_limit is null and cur is null then return json_build_object('applied', true, 'limit', null); end if;
  if p_limit is not null and (cur is null or p_limit <= cur) then
    update public.profiles set monthly_limit = p_limit, limit_next = null, limit_next_at = null where id = u;
    return json_build_object('applied', true, 'limit', p_limit);
  end if;
  update public.profiles set monthly_limit = cur, limit_next = p_limit, limit_next_at = now() + interval '24 hours' where id = u;
  return json_build_object('applied', false, 'limit', cur, 'next', p_limit, 'at', now() + interval '24 hours');
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
  perform public._notify(w.owner, 'shipped', '출고한 카드 ' || array_length(w.items, 1) || '장을 보냈어요', '곧 도착해요', w.id);
end $$;

-- ---------- 함수 실행 권한 ----------
revoke execute on all functions in schema public from public, anon, authenticated;
drop function if exists public.market(text, int);
drop function if exists public.buy_listing(uuid);
grant execute on function public.market(text, int, text), public.listing_detail(uuid), public.sweep() to anon, authenticated;
grant execute on function
  public.me(), public.set_nickname(text), public.my_vault(), public.my_batches(), public.my_ledger(),
  public.open_batch(), public.add_batch_item(uuid, text, text, text, text, text, int, text, jsonb), public.remove_batch_item(uuid), public.submit_batch(uuid, text),
  public.list_item(uuid, int), public.cancel_listing(uuid), public.buy_listing(uuid, int), public.request_withdraw(uuid[], text),
  public.start_auction(uuid, int, int), public.place_bid(uuid, int, int),
  public.make_offer(uuid, int), public.cancel_offer(uuid), public.respond_offer(uuid, boolean), public.my_activity(),
  public.add_wish(text), public.remove_wish(uuid), public.my_wishes(), public.my_notifications(int), public.read_notifications(),
  public.set_spend_limit(int),
  public.admin_queue(), public.admin_check_item(uuid, text, text, text), public.admin_find_user(text), public.admin_topup(uuid, bigint, text),
  public.admin_withdrawals(), public.admin_ship_withdrawal(uuid)
to authenticated;
