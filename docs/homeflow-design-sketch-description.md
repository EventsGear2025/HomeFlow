# homeFlow App Design Sketch Description

Use this as a copy-and-paste reference for someone sketching the product design.

## 1) What this app is

homeFlow is a household operations app built for Kenyan homes.

It has:
- A mobile app used by household owners and house managers.
- A separate web admin panel used by platform operators.

Core purpose:
- Keep a home running smoothly by managing supplies, shopping, meals, laundry, kids, utilities, staff, and notifications in one system.

## 2) Roles to represent in your sketch

- Owner:
  - Full access and controls.
  - Can set up household profile, invite others, manage billing/plan, and see owner-only sections.
- House Manager:
  - Operational access for daily tasks.
  - Sees a restricted subset of data/features compared with owner.

## 3) Visual language (important for style boards)

Overall feel:
- Clean, practical, calm, premium-but-friendly.

Color direction:
- Primary: deep navy/teal for headers, active states, important buttons.
- Surfaces: white and light-blue tinted backgrounds.
- Warning/accent: warm orange for alerts and urgent actions.

Component shape language:
- Rounded cards (roughly 12 to 20 radius).
- Pill chips for status and metadata.
- Floating action buttons for add/create actions.

Typography:
- Modern sans-serif with clear hierarchy (strong title weights, readable body text).

## 4) Main mobile flow to sketch

### A) Splash Screen

Layout:
- Full navy background.
- App icon in rounded square near upper-middle.
- Large app name and short tagline.
- Two large buttons near bottom:
  - Get Started
  - I already have an account

### B) Onboarding Carousel (5 slides)

Layout per slide:
- Top row: step pill ("x of 5") + Skip button.
- Center: large circular icon, headline, body text.
- Bottom: progress dots + primary button (Next / Get Started).

### C) Authentication

- Login and Sign Up support role-based entry.
- Tabs:
  - I'm a Homeowner
  - I'm a Manager
- Includes invite-code and OTP/email verification branches.
- Form style: rounded inputs, clean spacing, clear CTA.

### D) Main App Shell (post-login)

Global structure:
- Bottom navigation with 6 tabs:
  1. Home
  2. Supplies
  3. Shopping
  4. Laundry
  5. Meals
  6. Kids
- Left drawer for account + household controls.

### E) Home Dashboard

Top area:
- Collapsible gradient header.
- Household name, greeting, user avatar initial.
- Role pill + plan badge.
- Notification bell with unread badge.

Body sections:
- Quick Actions row.
- Home Status strip (low stock, meals today, laundry count, pending items).
- Sponsored ad strip.
- Analytics entry card (with Home Pro unlock behavior).
- Smart tips/reminders cards.

## 5) Feature screens to include in wireframes

### Supplies
- Category filters and search.
- Supply cards with status chips (enough/low/finished).
- Utility setup entry points where relevant.

### Shopping
- 4 internal tabs:
  - Buy Now
  - Requests
  - On Hold
  - History
- Price-compare action.
- Add/request item FAB.
- Card actions (approve/defer/mark bought).

### Meals
- 3 internal tabs:
  - Daily Log
  - Timetable
  - Nutrition Stats
- Date navigator with previous/next controls.
- Meal period progress strip.
- Log Meal FAB.

### Laundry
- 3 internal tabs:
  - Active
  - Stats
  - History
- Active loads grouped by bedroom.
- Add Load FAB.

### Kids
- Horizontal 7-day date strip.
- School readiness summary card with progress bar.
- Per-child routine cards.
- Add Child FAB (owner-focused).

### Utilities
- Scrollable utility sections (e.g., gas, drinking water, electricity, internet, metered water, service charge, rent, pay TV, custom utilities).
- Utility setup FAB.
- Utility analytics summary at top.
- Expandable section cards with setup/tracking controls.

### Notifications
- Grouped list sections:
  - Today
  - Yesterday
  - Earlier
- Card items with icon, message, time-ago text, unread dot.
- Actions: mark all read, clear all.

## 6) Secondary product: web admin panel (separate sketch)

Audience:
- Internal operators/admins, not household users.

Structure:
- Left navigation + content workspace.
- Top action button for quick actions.

Key admin pages:
- Dashboard
- Households
- Users
- Plans & Billing
- Analytics
- Presets
- Notifications
- Support
- Activity Logs
- Admin Users
- Ads
- Settings

Visual tone:
- Operational dashboard style with cards, tables, usage bars, alerts, and timeline blocks.

## 7) What makes the UX distinctive

- Role-aware visibility throughout the app.
- Heavy use of bottom sheets for add/edit/confirm flows.
- Operational + analytical blend (task execution plus upgradeable intelligence surfaces).
- Card-first information architecture that remains approachable despite high data density.

## 8) Fast sketch plan (if you need to draft quickly)

1. Draw the global shell once (app bar + bottom nav + drawer).
2. Create 4 reusable card templates:
   - Status card
   - List/action card
   - Analytics card
   - Empty-state card
3. Sketch one onboarding/auth path:
   - Splash -> Onboarding -> Sign Up/Login -> Home
4. Sketch one operational loop:
   - Low stock -> Shopping request -> Buy now -> History
5. Sketch one management loop:
   - Owner drawer -> Household access/invites -> Staff/manager visibility

---

You can copy this entire document directly for handoff to a designer, PM, or illustrator.
