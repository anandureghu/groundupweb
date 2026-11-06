# Admin web portal — Design

**Date:** 2026-11-06
**Status:** Draft (pending approval)
**App:** `web/` (Next.js), reads the same Supabase project as `app/`

## Goal

Give Groundup Society admins, founders, and developers one web URL to see what's
happening in the business and manage it — without digging through Supabase
directly or asking a developer. The mobile app's admin area stays as-is;
over time, admin work moves to web and the mobile admin area is used less,
but nothing is removed from mobile in this phase.

## Why now

User onboarding is growing day over day and there's currently no way to see
trends (signups, orders, revenue, redemptions, referrals) or handle
operational work (support requests, auditing changes) without reading the
database by hand.

## Locked decisions

| Topic | Choice |
|-------|--------|
| Scope boundary (this phase) | New analytics/reporting that doesn't exist anywhere today, **plus** customer & staff management rebuilt in web (parity with mobile). Stores/products/categories/coupon-definitions/banners/challenges/merch CRUD and legal/notification-template editors stay mobile-only for now. |
| Mobile app | Untouched. No removals, no required changes in this phase. |
| Auth | Same Supabase account used in the app today. Access = `profiles.staff_role = 'admin'` (the same check `assert_admin_access()` already enforces for mobile's admin RPCs). |
| Access control | Binary. Anyone with an admin account gets full access — no read-only/limited roles. |
| URL | `/admin` path inside the existing `web` Next.js app (e.g. `groundup.com/admin`) — not a new subdomain. *My call; easy to move later if you want isolation.* |
| Data access pattern | Reads and simple writes: new Postgres RPCs (`security definer`, start with `perform public.assert_admin_access();`), called from a **session-authenticated** Supabase client on the server — same pattern mobile's read RPCs already use (`list_customers`, `list_staff_members`, `get_admin_onboarding_analytics`). User-account mutations (create staff, disable/enable customer or staff): reuse the **existing** `admin-customers` / `admin-staff` Supabase Edge Functions mobile already calls — those use the Auth Admin API (`auth.admin.createUser`, `auth.admin.updateUserById` to ban/unban), which a plain RPC can't do. Nothing new on the service-role side; web just becomes a second caller of the same shared edge functions. |
| Audit log | New, and only covers actions taken through the **web portal** going forward. Does not retroactively log mobile admin actions. |
| Support inbox | View + status triage (new/in_progress/closed) only. No outbound email reply from the portal in this phase. *My call.* |
| Staff performance (orders per staff member) | **Deferred out of this phase.** `orders` has no staff-attribution column today; adding one means changing the mobile order-creation flow, which goes beyond "keep the app as it is." Flagging this — say the word and it becomes a small follow-up phase. |
| UI | Reuse `web`'s existing Tailwind v4 + shadcn/radix setup (`components.json` already configured) rather than introducing a new design system. |

## Phase 1 scope

### 1. Admin auth
- Login page at `/admin/login` using Supabase Auth (email/password — same
  credentials as the app).
- Session via `@supabase/ssr` (already a dependency, unused so far) so
  `auth.uid()` is populated server-side and `assert_admin_access()` works
  exactly as it does for mobile.
- Middleware on `/admin/*` redirects unauthenticated users to
  `/admin/login`, and redirects authenticated non-admins (customers,
  `staff_role = 'staff'`) to a plain "not authorized" page.

### 2. Overview / growth dashboard (`/admin`)
- Signups over time (customers, staff), totals, trend — extends the
  existing `get_admin_onboarding_analytics()` RPC with a time-series
  breakdown instead of totals only.
- Active customers, active staff, pending/incomplete signups.

### 3. Customer management (`/admin/customers`)
- List + search (reuses `list_customers()`), detail view. Enable/disable
  calls the existing `admin-customers` edge function (same one mobile
  calls) — parity with `app/app/(app)/admin/customers/`.
- Adds: order history and reward-transaction history on the detail page
  (not present on mobile's customer detail today — a genuinely new view,
  since the data already exists in `orders` / `reward_transactions`).

### 4. Staff management (`/admin/staff`)
- List + search (reuses `list_staff_members()`), detail view. Create and
  enable/disable call the existing `admin-staff` edge function (same one
  mobile calls) — parity with `app/app/(app)/admin/staff/`.

### 5. Order & revenue analytics (`/admin/orders`)
- Orders and revenue over time, breakdown by store and status, recent
  orders list. New RPC(s) over `orders` / `order_items` — nothing like
  this exists in any admin surface today.

### 6. Rewards & redemption analytics (`/admin/rewards`)
- Points issued vs. redeemed over time, `reward_transactions` ledger
  view, product-for-points redemption activity (`orders.is_redemption` /
  `order_items.points_redeemed`).

### 7. Coupon analytics (`/admin/coupons`)
- Redemption counts/rates per `coupon_definitions`, using
  `coupon_redemptions`. Read-only in this phase (no coupon creation —
  that stays on mobile).

### 8. Challenge analytics (`/admin/challenges`)
- Completion rates and a leaderboard from `member_challenge_progress`.
  Read-only, same reasoning as coupons.

### 9. Referral analytics (`/admin/referrals`)
- Referral signups over time, top referrers (staff and customers) —
  extends the existing `referred_by_id` data already surfaced partially
  in `get_admin_onboarding_analytics()` / `get_admin_customer_referrer()`.

### 10. Support inbox (`/admin/support`)
- List/view `support_requests`, update `status`
  (`new` → `in_progress` → `closed`). New RPCs needed since that table
  currently grants `service_role` only.

### 11. Audit log (`/admin/audit-log`)
- New `admin_audit_log` table:
  ```sql
  create table public.admin_audit_log (
    id uuid primary key default gen_random_uuid(),
    actor_id uuid not null references public.profiles(id),
    actor_email text not null,
    action text not null,        -- e.g. 'customer.disable', 'staff.create'
    entity_type text not null,   -- e.g. 'customer', 'staff', 'support_request'
    entity_id text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
  );
  ```
- Written via a `log_admin_action(...)` RPC (same `assert_admin_access()`
  pattern) called after every mutating action taken through the portal
  (disable/enable customer or staff, create staff, update support
  request status, etc.) — including after edge-function calls succeed.
  If the audit-log write itself fails, it shouldn't block or roll back
  the underlying action (the ban/create already happened); log the
  failure server-side and surface it, rather than retrying the user-facing
  action.
- Viewer: filterable list (by actor, action, entity, date range).

### 12. CSV export (stretch within Phase 1)
- Export buttons on customers, staff, orders, and support-request list
  views. Lowest priority item in this phase — fine to land last or slip
  to a fast follow if time-boxed.

## Migration source of truth

`app/supabase/migrations/` is the single source of truth for this
project's schema — confirmed live project (`dkufmqlvaqgxzptqvtvv.supabase.co`)
matches what both `app/.env` and `web/.env` already point at. All new SQL
for this design (the `admin_audit_log` table, new RPCs) gets added there.
`web/supabase/` is stale local CLI scaffolding pointed at a different,
unused project config — leave it alone, don't try to reconcile it.

## Security note (not fixing now, flagging it)

Several core tables (`orders`, `reward_transactions`, `profiles`, etc.)
currently have RLS **disabled** and are granted to the `authenticated`
role directly — mobile's admin screens are only gated by client-side UI
checks, not the database. Routing all new admin reads/writes through
`assert_admin_access()`-guarded RPCs (as this design does) means the new
web portal doesn't add to that gap, but it also doesn't close the
existing one. Worth a dedicated hardening pass later; out of scope here.

## What's left to the builder

- Exact RPC names/signatures for the new analytics functions (follow the
  existing `get_admin_*` / `list_admin_*` naming loosely used today).
- Chart library choice for time-series views (none currently in `web`'s
  dependencies).
- Pagination/filtering details on list views.
- Exact layout/navigation shell for `/admin/*` (sidebar vs. top nav, etc.)
  using the existing shadcn/radix components.
- Loading/empty/error states.
- Audit log filter UI details.
