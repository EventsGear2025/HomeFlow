-- ============================================================
-- homeFlow – Ad Offers table
-- Run AFTER docs/supabase-all-tables.sql
-- ============================================================
-- Stores sponsored product offers shown on the app home screen.
-- Advertisers (supermarkets, suppliers) manage slots via the admin panel.
-- Prices are stored in KES cents (integer × 100) to match the rest of the
-- schema (e.g. subscription_plans.price_cents).
-- ============================================================

-- ------------------------------------------------------------
-- TABLE
-- ------------------------------------------------------------

create table if not exists public.ad_offers (
  id              uuid        primary key default gen_random_uuid(),
  advertiser      text        not null,                        -- e.g. 'Naivas', 'Carrefour'
  accent_hex      text        not null default '#1B8A4A',      -- brand colour for the card
  product_name    text        not null,
  old_price_cents integer     not null check (old_price_cents > 0),
  new_price_cents integer     not null check (new_price_cents > 0),
  currency        text        not null default 'KES',
  placement       text        not null default 'home',         -- future: 'supplies', 'shopping', etc.
  is_active       boolean     not null default true,
  display_order   integer     not null default 0,              -- lower = shown first
  category        text        not null default 'Other',        -- matches AppConstants.supplyCategories
  expires_at      timestamptz,                                 -- null = never expires
  created_at      timestamptz not null default now()
);

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------

alter table public.ad_offers enable row level security;

drop policy if exists "Authenticated users can read active ad offers"
  on public.ad_offers;

drop policy if exists "Admins can manage ad offers"
  on public.ad_offers;

-- Any logged-in user can read active offers.
create policy "Authenticated users can read active ad offers"
  on public.ad_offers
  for select
  using (
    auth.role() = 'authenticated'
    and is_active = true
    and (expires_at is null or expires_at > now())
  );

-- Internal staff with app_role=admin can read all rows and manage offers.
create policy "Admins can manage ad offers"
  on public.ad_offers
  for all
  using ((auth.jwt() ->> 'app_role') = 'admin')
  with check ((auth.jwt() ->> 'app_role') = 'admin');

-- ------------------------------------------------------------
-- INDEX
-- ------------------------------------------------------------

create index if not exists ad_offers_placement_active_order_idx
  on public.ad_offers (placement, is_active, display_order);

-- If you already ran this file before the category column was added, run this once:
-- alter table public.ad_offers add column if not exists category text not null default 'Other';

-- ============================================================
-- SEED DATA
-- 4 best-value Naivas offers + 4 best-value Carrefour offers.
-- Prices in KES cents (KES 1,199 → 119900).
-- ============================================================

insert into public.ad_offers
  (id, advertiser, accent_hex, product_name, old_price_cents, new_price_cents, currency, placement, is_active, display_order, category)
values
  -- ── Naivas (brand green #1B8A4A) ───────────────────────────────────────
  (
    'ad000000-0000-0000-0000-000000000001',
    'Naivas',
    '#1B8A4A',
    'Sunrice Basmati Rice 5kg',
    182500,   -- KES 1,825
    119900,   -- KES 1,199  (34% off)
    'KES', 'home', true, 1, 'Dry Foods & Cereals'
  ),
  (
    'ad000000-0000-0000-0000-000000000002',
    'Naivas',
    '#1B8A4A',
    'Jamii Pure Mwea Pishori Rice 5Kg',
    145000,   -- KES 1,450
    99900,    -- KES 999    (31% off)
    'KES', 'home', true, 2, 'Dry Foods & Cereals'
  ),
  (
    'ad000000-0000-0000-0000-000000000003',
    'Naivas',
    '#1B8A4A',
    'Highlands Lemon Drink 2L',
    34900,    -- KES 349
    24900,    -- KES 249    (28% off)
    'KES', 'home', true, 3, 'Breakfast Staples'
  ),
  (
    'ad000000-0000-0000-0000-000000000004',
    'Naivas',
    '#1B8A4A',
    'Rina Vegetable Oil 5 Ltr',
    160000,   -- KES 1,600
    119900,   -- KES 1,199  (25% off)
    'KES', 'home', true, 4, 'Cooking Essentials'
  ),

  -- ── Carrefour (brand red #E2001A) ───────────────────────────────────────
  (
    'ad000000-0000-0000-0000-000000000005',
    'Carrefour',
    '#E2001A',
    'Velvex Hand Wash Floral 400ML',
    22000,    -- KES 220
    13200,    -- KES 132    (40% off)
    'KES', 'home', true, 5, 'Personal Care'
  ),
  (
    'ad000000-0000-0000-0000-000000000006',
    'Carrefour',
    '#E2001A',
    'Persil Hand Wash Powder Rose 500G',
    25500,    -- KES 255
    15300,    -- KES 153    (40% off)
    'KES', 'home', true, 6, 'Laundry & Cleaning'
  ),
  (
    'ad000000-0000-0000-0000-000000000007',
    'Carrefour',
    '#E2001A',
    'Ariel Liquid Auto Wash Original 3L',
    219900,   -- KES 2,199
    148500,   -- KES 1,485  (32% off)
    'KES', 'home', true, 7, 'Laundry & Cleaning'
  ),
  (
    'ad000000-0000-0000-0000-000000000008',
    'Carrefour',
    '#E2001A',
    'Daima Butter Salted 500G',
    77000,    -- KES 770
    57500,    -- KES 575    (25% off)
    'KES', 'home', true, 8, 'Dairy & Eggs'
  )
on conflict (id) do nothing;

-- ============================================================
-- DONE
-- ============================================================
