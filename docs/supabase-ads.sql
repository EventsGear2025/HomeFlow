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
-- 5 current Naivas offers + 5 current Carrefour offers.
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
    'Naivas Fino UHT Milk 500ML',
    5200,     -- KES 52
    4900,     -- KES 49
    'KES', 'home', true, 1, 'Dairy & Eggs'
  ),
  (
    'ad000000-0000-0000-0000-000000000002',
    'Naivas',
    '#1B8A4A',
    'Celine Petals Tissue 10 Pack',
    44500,    -- KES 445
    22500,    -- KES 225
    'KES', 'home', true, 2, 'Personal Care'
  ),
  (
    'ad000000-0000-0000-0000-000000000003',
    'Naivas',
    '#1B8A4A',
    'Celine Serviettes 100 Sheets',
    14000,    -- KES 140
    9900,     -- KES 99
    'KES', 'home', true, 3, 'Kitchen Cleaning'
  ),
  (
    'ad000000-0000-0000-0000-000000000004',
    'Naivas',
    '#1B8A4A',
    'Sunrice Basmati Rice 5Kg',
    182500,   -- KES 1,825
    129900,   -- KES 1,299
    'KES', 'home', true, 4, 'Dry Foods & Cereals'
  ),
  (
    'ad000000-0000-0000-0000-000000000005',
    'Naivas',
    '#1B8A4A',
    'Rina Vegetable Oil 5L',
    160000,   -- KES 1,600
    139900,   -- KES 1,399
    'KES', 'home', true, 5, 'Cooking Essentials'
  ),

  -- ── Carrefour (brand red #E2001A) ───────────────────────────────────────
  (
    'ad000000-0000-0000-0000-000000000006',
    'Carrefour',
    '#E2001A',
    'Fresh Chicken Drumsticks (per kg)',
    87900,    -- KES 879
    64900,    -- KES 649
    'KES', 'home', true, 6, 'Meat & Protein'
  ),
  (
    'ad000000-0000-0000-0000-000000000007',
    'Carrefour',
    '#E2001A',
    'Softleaf Virgin Toilet Paper Unwrap x10',
    55700,    -- KES 557
    38900,    -- KES 389
    'KES', 'home', true, 7, 'Personal Care'
  ),
  (
    'ad000000-0000-0000-0000-000000000008',
    'Carrefour',
    '#E2001A',
    'Velvex Toilet Rolls White x10',
    57700,    -- KES 577
    40300,    -- KES 403
    'KES', 'home', true, 8, 'Personal Care'
  ),
  (
    'ad000000-0000-0000-0000-000000000009',
    'Carrefour',
    '#E2001A',
    'Clorox Lemon Liquid 750ML',
    41500,    -- KES 415
    29000,    -- KES 290
    'KES', 'home', true, 9, 'Laundry & Cleaning'
  ),
  (
    'ad000000-0000-0000-0000-000000000010',
    'Carrefour',
    '#E2001A',
    'Huggies Dry Comfort Diapers Jumbo',
    208900,   -- KES 2,089
    146200,   -- KES 1,462
    'KES', 'home', true, 10, 'Baby & Kids'
  )
on conflict (id) do update
set advertiser = excluded.advertiser,
    accent_hex = excluded.accent_hex,
    product_name = excluded.product_name,
    old_price_cents = excluded.old_price_cents,
    new_price_cents = excluded.new_price_cents,
    currency = excluded.currency,
    placement = excluded.placement,
    is_active = excluded.is_active,
    display_order = excluded.display_order,
    category = excluded.category;

-- ============================================================
-- DONE
-- ============================================================
