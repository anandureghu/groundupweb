# Admin Portal Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `/admin` section of the `web` Next.js app: admin login, a shared shell, customer management, staff management, a growth/overview dashboard, and an audit log — the people-management parity pieces plus the foundation every later analytics module builds on.

**Architecture:** Next.js Server Components + Server Actions under `web/app/admin/`, gated by `@supabase/ssr` session middleware and a `requireAdmin()` guard. Reads/aggregations go through new Postgres RPCs (`security definer`, `assert_admin_access()`) called with the signed-in admin's own session — mirrors the pattern `app/supabase/migrations/*` already uses for `list_customers()` etc. User-account mutations (create staff, disable/enable) call the existing `admin-customers` / `admin-staff` Supabase Edge Functions mobile already uses, with the admin's access token forwarded as the bearer.

**Tech Stack:** Next.js 16 (App Router), React 19, `@supabase/ssr` + `@supabase/supabase-js`, Tailwind v4 + shadcn/radix (already configured via `components.json`), Vitest (new — for pure-logic unit tests), `recharts` (new — for the growth chart).

**Spec:** [web/docs/superpowers/specs/2026-11-06-admin-portal-design.md](../specs/2026-11-06-admin-portal-design.md)

## Global Constraints

- Schema source of truth is `app/supabase/migrations/`; new SQL for this plan lives there, applied to the shared project (`dkufmqlvaqgxzptqvtvv.supabase.co`), not in `web/supabase/` (stale/unused).
- No existing automated test suite in `web` or `app`. This plan adds Vitest for unit-testable TypeScript logic (pure functions only — decision/shaping logic extracted out of Server Components and Actions). Framework glue (middleware, Server Actions, pages) and all SQL are verified manually — each task spells out the exact manual check.
- Admin access = `profiles.staff_role = 'admin'` for page/route gating (per design doc). The reused edge functions independently check `auth.users.app_metadata.roles` containing `'admin'` — both are set together whenever a staff/admin account is created, so this is a documented fact, not a new mechanism to build.
- Reuse the existing `@/*` path alias, existing env vars (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`/`PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`) — no new env vars needed.
- Pull additional shadcn components via `npx shadcn@latest add <name>` rather than hand-rolling primitives; only `button` and `dialog` exist today.
- Out of scope for this plan (deferred to a follow-up plan): order/revenue analytics, rewards/redemption analytics, coupon analytics, challenge analytics, referral analytics, support inbox, CSV export — design doc sections 5–12 except the audit log (section 11, included here) and the customer/staff order-history snippets described below.

## Review Focus

- A signed-in customer or `staff_role = 'staff'` account requesting any `/admin/*` URL directly must never see admin content, even briefly.
- An admin's session cookie expiring mid-visit must redirect to login cleanly, not throw an unhandled server error.
- An admin disabling *their own* account (self-lockout) must be rejected before the edge function call — the spec is silent on this but it's a real foot-gun for a destructive action.
- Creating a staff account with an email that already exists must surface the edge function's actual error message in the UI, not crash the page.
- `log_admin_action` failing after a mutating action already succeeded (edge function ban/create already happened) must not undo the action or block the response to the user — just get logged server-side.

---

## Task 1: Supabase session plumbing + admin gate

**Files:**
- Create: `web/lib/supabase/server.ts`
- Create: `web/lib/supabase/middleware.ts`
- Create: `web/middleware.ts`
- Create: `web/lib/admin/gate.ts`
- Create: `web/lib/admin/auth.ts`
- Test: `web/lib/admin/gate.test.ts`
- Modify: `web/package.json` (add `vitest`, `@vitejs/plugin-react` as devDependencies; add `"test": "vitest run"` script)

**Interfaces:**
- Produces: `createServerSupabaseClient(): Promise<SupabaseClient>` (server.ts) — anon-key client bound to the request's cookies via `@supabase/ssr`'s `createServerClient`.
- Produces: `resolveAdminGateResult(session: { userId: string } | null, profile: { staffRole: string | null } | null): 'allow' | 'login' | 'unauthorized'` (gate.ts).
- Produces: `requireAdmin(): Promise<{ userId: string; email: string }>` (auth.ts) — calls `createServerSupabaseClient()`, `supabase.auth.getUser()`, queries `profiles` for `staff_role`/`email` by id, runs the result through `resolveAdminGateResult`, and `redirect('/admin/login')` or `redirect('/admin/unauthorized')` (from `next/navigation`) for the non-`'allow'` cases. Returns `{ userId, email }` on `'allow'`.

- [ ] **Step 1: Write the failing tests for `resolveAdminGateResult`**

```ts
import { describe, it, expect } from "vitest";
import { resolveAdminGateResult } from "./gate";

describe("resolveAdminGateResult", () => {
  it("returns 'login' when there is no session", () => {
    expect(resolveAdminGateResult(null, null)).toBe("login");
  });

  it("returns 'unauthorized' when the session has no profile", () => {
    expect(resolveAdminGateResult({ userId: "u1" }, null)).toBe("unauthorized");
  });

  it("returns 'unauthorized' when staffRole is not 'admin'", () => {
    expect(
      resolveAdminGateResult({ userId: "u1" }, { staffRole: "staff" }),
    ).toBe("unauthorized");
    expect(
      resolveAdminGateResult({ userId: "u1" }, { staffRole: null }),
    ).toBe("unauthorized");
  });

  it("returns 'allow' when staffRole is 'admin'", () => {
    expect(
      resolveAdminGateResult({ userId: "u1" }, { staffRole: "admin" }),
    ).toBe("allow");
  });
});
```

- [ ] **Step 2: Add Vitest, run test to verify it fails**

Run: `npm install -D vitest @vitejs/plugin-react --prefix web && cd web && npx vitest run lib/admin/gate.test.ts`
Expected: FAIL with "Cannot find module './gate'" (or similar — file doesn't exist yet).

- [ ] **Step 3: Implement `resolveAdminGateResult` in `web/lib/admin/gate.ts`**

Pure function, no imports beyond its own types — exactly the four branches tested above.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd web && npx vitest run lib/admin/gate.test.ts`
Expected: PASS, 4 tests.

- [ ] **Step 5: Implement `createServerSupabaseClient()` in `web/lib/supabase/server.ts`**

Use `createServerClient` from `@supabase/ssr` with `NEXT_PUBLIC_SUPABASE_URL` / the anon key (via existing `getSupabasePublicEnv()` from `web/lib/supabase/env.ts`), wiring `cookies()` from `next/headers` for `getAll`/`setAll` per the `@supabase/ssr` Next.js App Router pattern.

- [ ] **Step 6: Implement `updateSession` in `web/lib/supabase/middleware.ts` and wire `web/middleware.ts`**

Follow the standard `@supabase/ssr` middleware recipe: build a `NextResponse`, create a middleware-scoped Supabase client against the incoming `NextRequest`/outgoing response cookies, call `supabase.auth.getUser()` to refresh the session, return the response. `web/middleware.ts` exports `export const config = { matcher: ["/admin/:path*"] }` and delegates to `updateSession`.

- [ ] **Step 7: Implement `requireAdmin()` in `web/lib/admin/auth.ts`**

```ts
export async function requireAdmin(): Promise<{ userId: string; email: string }>
```

Calls `createServerSupabaseClient()`, `getUser()`, selects `staff_role, email` from `profiles` by `id = user.id`, passes through `resolveAdminGateResult`, redirects on non-`'allow'`.

- [ ] **Step 8: Verify the build type-checks**

Run: `cd web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git -C web add lib/supabase/server.ts lib/supabase/middleware.ts middleware.ts lib/admin/gate.ts lib/admin/gate.test.ts lib/admin/auth.ts package.json package-lock.json
git -C web commit -m "feat: add admin session plumbing and access gate"
```

---

## Task 2: Admin login page

**Files:**
- Create: `web/app/admin/login/page.tsx`
- Create: `web/app/admin/login/actions.ts`

**Interfaces:**
- Consumes: `createServerSupabaseClient()`, `requireAdmin()` (Task 1).
- Produces: `signInAdmin(formData: FormData): Promise<{ error: string } | never>` (Server Action — on success it `redirect('/admin')`, so the success path never returns a value to the caller).

- [ ] **Step 1: Implement `signInAdmin` in `web/app/admin/login/actions.ts`**

Server Action (`"use server"`). Reads `email`/`password` from `FormData`, calls `createServerSupabaseClient().auth.signInWithPassword(...)`. On auth error, return `{ error: "Incorrect email or password." }`. On success, re-check admin access the same way `requireAdmin()` does (query `profiles.staff_role`); if not `'admin'`, call `supabase.auth.signOut()` and return `{ error: "This account does not have admin access." }`. Otherwise `redirect("/admin")`.

- [ ] **Step 2: Implement `web/app/admin/login/page.tsx`**

Server Component rendering a form (email, password, submit) that calls `signInAdmin` via `useActionState`/form `action`, showing the returned `error` string if present. Reuse existing `components/ui/button.tsx`; pull `npx shadcn@latest add input label card` for the form fields if not already present.

- [ ] **Step 3: Manual verification**

Run `cd web && npm run dev`, visit `/admin/login`:
- Submit with a wrong password → error message shown, stays on page.
- Submit with a real customer account's credentials (not staff) → "This account does not have admin access." shown.
- Submit with a real admin account's credentials → redirected to `/admin` (404/blank is fine — Task 3 builds the page).

- [ ] **Step 4: Commit**

```bash
git -C web add app/admin/login
git -C web commit -m "feat: add admin login page"
```

---

## Task 3: Admin shell layout

**Files:**
- Create: `web/app/admin/layout.tsx`
- Create: `web/app/admin/unauthorized/page.tsx`
- Create: `web/components/admin/admin-nav.tsx`
- Create: `web/app/admin/sign-out-action.ts`

**Interfaces:**
- Consumes: `requireAdmin()` (Task 1).
- Produces: nav links to `/admin` (Overview), `/admin/customers`, `/admin/staff`, `/admin/audit-log` — later tasks fill these routes in; linking to not-yet-built routes is fine (Next.js 404s until they exist).

- [ ] **Step 1: Implement `web/app/admin/unauthorized/page.tsx`**

Plain Server Component: "You don't have admin access." plus a link back to `/admin/login`.

- [ ] **Step 2: Implement `signOutAdmin` Server Action in `web/app/admin/sign-out-action.ts`**

`"use server"`, calls `createServerSupabaseClient().auth.signOut()`, then `redirect("/admin/login")`.

- [ ] **Step 3: Implement `web/components/admin/admin-nav.tsx`**

Client or Server Component rendering the four nav links plus a sign-out button wired to `signOutAdmin`.

- [ ] **Step 4: Implement `web/app/admin/layout.tsx`**

Server Component: `await requireAdmin()`, render `<AdminNav />` plus `{children}` in a basic shell (sidebar or top bar — builder's call on layout, per design doc).

- [ ] **Step 5: Manual verification**

With dev server running: visit `/admin` while logged out → redirected to `/admin/login`. Log in as admin → shell + nav renders. Click sign out → redirected to `/admin/login`, and `/admin` now redirects again.

- [ ] **Step 6: Commit**

```bash
git -C web add app/admin/layout.tsx app/admin/unauthorized app/admin/sign-out-action.ts components/admin/admin-nav.tsx
git -C web commit -m "feat: add admin shell layout and sign-out"
```

---

## Task 4: Audit log table, RPCs, and server helper

**Files:**
- Create: `app/supabase/migrations/20261106120000_admin_portal_audit_log.sql`
- Create: `web/lib/admin/audit-log.ts`
- Test: `web/lib/admin/audit-log.test.ts`

**Interfaces:**
- Produces (SQL): table `public.admin_audit_log`; RPCs `log_admin_action(p_action text, p_entity_type text, p_entity_id text, p_metadata jsonb)` returns `uuid`; `list_admin_audit_log(p_limit integer default 50, p_before timestamptz default null)` returns rows `(id uuid, actor_email text, action text, entity_type text, entity_id text, metadata jsonb, created_at timestamptz)`.
- Produces (TS): `toAuditLogRpcArgs(input: { action: string; entityType: string; entityId?: string; metadata?: Record<string, unknown> }): { p_action: string; p_entity_type: string; p_entity_id: string | null; p_metadata: Record<string, unknown> }`; `logAdminAction(client: Pick<SupabaseClient, "rpc">, input: { action: string; entityType: string; entityId?: string; metadata?: Record<string, unknown> }): Promise<void>` — takes the Supabase client as a parameter (callers pass `await createServerSupabaseClient()`) so the error-swallowing path is unit-testable; catches and `console.error`s any RPC error rather than throwing (per Review Focus: must not block the caller's response). Tasks 5–6 call it as `logAdminAction(supabase, { action, entityType, entityId })` using the same client instance they already hold for the page/action's other queries.

- [ ] **Step 1: Write the migration `app/supabase/migrations/20261106120000_admin_portal_audit_log.sql`**

```sql
create table public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles(id),
  actor_email text not null,
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index admin_audit_log_created_at_idx on public.admin_audit_log (created_at desc);

alter table public.admin_audit_log enable row level security;
revoke all on table public.admin_audit_log from anon, authenticated;
grant select, insert on table public.admin_audit_log to service_role;

create or replace function public.log_admin_action(
  p_action text,
  p_entity_type text,
  p_entity_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_email text;
begin
  perform public.assert_admin_access();

  select email into v_email from public.profiles where id = auth.uid();

  insert into public.admin_audit_log (actor_id, actor_email, action, entity_type, entity_id, metadata)
  values (auth.uid(), coalesce(v_email, ''), p_action, p_entity_type, p_entity_id, coalesce(p_metadata, '{}'::jsonb))
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.log_admin_action(text, text, text, jsonb) to authenticated, service_role;

create or replace function public.list_admin_audit_log(
  p_limit integer default 50,
  p_before timestamptz default null
)
returns table (
  id uuid,
  actor_email text,
  action text,
  entity_type text,
  entity_id text,
  metadata jsonb,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  return query
  select l.id, l.actor_email, l.action, l.entity_type, l.entity_id, l.metadata, l.created_at
  from public.admin_audit_log l
  where p_before is null or l.created_at < p_before
  order by l.created_at desc
  limit greatest(1, least(p_limit, 200));
end;
$$;

grant execute on function public.list_admin_audit_log(integer, timestamptz) to authenticated, service_role;
```

- [ ] **Step 2: Apply the migration locally and verify by hand**

Run: `cd app && supabase db reset`
Then, with an admin session (e.g. via `supabase db execute` or the SQL editor in local Studio at `http://127.0.0.1:54323`), run `select public.log_admin_action('test.action', 'test', 'abc', '{"x":1}'::jsonb);` as an authenticated admin role and confirm it returns a `uuid` and a row appears in `admin_audit_log`. Confirm `select public.list_admin_audit_log(10, null);` returns that row.
Expected: row present with expected columns; calling either function as a non-admin raises "Admin access required."

- [ ] **Step 3: Write the failing test for `toAuditLogRpcArgs`**

```ts
import { describe, it, expect } from "vitest";
import { toAuditLogRpcArgs } from "./audit-log";

describe("toAuditLogRpcArgs", () => {
  it("maps required fields and defaults optional ones", () => {
    expect(toAuditLogRpcArgs({ action: "customer.disable", entityType: "customer" })).toEqual({
      p_action: "customer.disable",
      p_entity_type: "customer",
      p_entity_id: null,
      p_metadata: {},
    });
  });

  it("passes through entityId and metadata when given", () => {
    expect(
      toAuditLogRpcArgs({
        action: "staff.create",
        entityType: "staff",
        entityId: "u1",
        metadata: { storeId: "s1" },
      }),
    ).toEqual({
      p_action: "staff.create",
      p_entity_type: "staff",
      p_entity_id: "u1",
      p_metadata: { storeId: "s1" },
    });
  });
});
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd web && npx vitest run lib/admin/audit-log.test.ts`
Expected: FAIL — module has no export `toAuditLogRpcArgs`.

- [ ] **Step 5: Write the failing test for `logAdminAction`'s non-throwing error path (Review Focus: audit log failure must not block the caller)**

```ts
import { describe, it, expect, vi } from "vitest";
import { logAdminAction } from "./audit-log";

describe("logAdminAction", () => {
  it("does not throw when the RPC call fails, and logs the error", async () => {
    const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const client = { rpc: vi.fn().mockResolvedValue({ error: new Error("boom") }) };

    await expect(
      logAdminAction(client, { action: "customer.disable", entityType: "customer" }),
    ).resolves.toBeUndefined();
    expect(consoleSpy).toHaveBeenCalled();
  });

  it("calls rpc with the mapped args on the happy path", async () => {
    const client = { rpc: vi.fn().mockResolvedValue({ error: null }) };

    await logAdminAction(client, { action: "staff.create", entityType: "staff", entityId: "u1" });

    expect(client.rpc).toHaveBeenCalledWith("log_admin_action", {
      p_action: "staff.create",
      p_entity_type: "staff",
      p_entity_id: "u1",
      p_metadata: {},
    });
  });
});
```

- [ ] **Step 6: Implement `toAuditLogRpcArgs` and `logAdminAction` in `web/lib/admin/audit-log.ts`**

`logAdminAction(client, input)` calls `client.rpc("log_admin_action", toAuditLogRpcArgs(input))`; if the result has an `error`, `console.error("logAdminAction failed", error)` and return — never throw, never let a rejected promise escape.

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd web && npx vitest run lib/admin/audit-log.test.ts`
Expected: PASS, 4 tests.

- [ ] **Step 8: Commit**

```bash
git -C app add supabase/migrations/20261106120000_admin_portal_audit_log.sql
git -C app commit -m "feat: add admin audit log table and RPCs"
git -C web add lib/admin/audit-log.ts lib/admin/audit-log.test.ts
git -C web commit -m "feat: add logAdminAction server helper"
```

---

## Task 5: Customer management

**Files:**
- Create: `app/supabase/migrations/20261106130000_admin_customer_detail.sql`
- Create: `web/lib/admin/edge-functions.ts`
- Create: `web/lib/admin/self-action-guard.ts`
- Test: `web/lib/admin/self-action-guard.test.ts`
- Test: `web/lib/admin/edge-functions.test.ts`
- Create: `web/app/admin/customers/page.tsx`
- Create: `web/app/admin/customers/[id]/page.tsx`
- Create: `web/app/admin/customers/actions.ts`

**Interfaces:**
- Produces (SQL): `get_admin_customer_orders(p_customer_id uuid, p_limit integer default 20)` returns `(id uuid, order_number text, store_name text, status text, total_cents integer, created_at timestamptz)`; `get_admin_customer_reward_transactions(p_customer_id uuid, p_limit integer default 20)` returns `(id uuid, type text, points integer, balance_after integer, description text, created_at timestamptz)`. Both `security definer`, `assert_admin_access()`.
- Produces (TS): `assertNotSelf(targetUserId: string, actingUserId: string): void` (throws `Error("You can't do this to your own account.")` when equal) — reused by Task 6.
- Produces (TS): `callAdminEdgeFunction<T>(name: "admin-customers" | "admin-staff", payload: object, accessToken: string): Promise<T>` (reused by Task 6) — POSTs to `${NEXT_PUBLIC_SUPABASE_URL}/functions/v1/${name}` with `Authorization: Bearer ${accessToken}` and `apikey: <anon key>` headers; on non-2xx response, throws `Error(body.error ?? "Request failed.")`.
- Consumes: `requireAdmin()`, `createServerSupabaseClient()`, `logAdminAction()` (Tasks 1, 4).

- [ ] **Step 1: Write the failing test for `assertNotSelf`**

```ts
import { describe, it, expect } from "vitest";
import { assertNotSelf } from "./self-action-guard";

describe("assertNotSelf", () => {
  it("throws when target and actor are the same user", () => {
    expect(() => assertNotSelf("u1", "u1")).toThrow(
      "You can't do this to your own account.",
    );
  });

  it("does not throw for different users", () => {
    expect(() => assertNotSelf("u1", "u2")).not.toThrow();
  });
});
```

- [ ] **Step 2: Run test, verify it fails; implement `assertNotSelf`; run again to verify it passes**

Run: `cd web && npx vitest run lib/admin/self-action-guard.test.ts` (fails, then passes after implementing in `web/lib/admin/self-action-guard.ts`).

- [ ] **Step 3: Write the failing test for `callAdminEdgeFunction` error mapping**

```ts
import { describe, it, expect, vi, afterEach } from "vitest";
import { callAdminEdgeFunction } from "./edge-functions";

afterEach(() => vi.restoreAllMocks());

describe("callAdminEdgeFunction", () => {
  it("throws the edge function's error message on a non-2xx response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ error: "Admin access required." }), {
          status: 403,
        }),
      ),
    );

    await expect(
      callAdminEdgeFunction("admin-customers", { action: "disable", userId: "u1" }, "token"),
    ).rejects.toThrow("Admin access required.");
  });

  it("returns the parsed JSON body on success", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ userId: "u1", disabled: true }), { status: 200 }),
      ),
    );

    await expect(
      callAdminEdgeFunction("admin-customers", { action: "disable", userId: "u1" }, "token"),
    ).resolves.toEqual({ userId: "u1", disabled: true });
  });
});
```

- [ ] **Step 4: Run test, verify it fails; implement `callAdminEdgeFunction`; run again to verify it passes**

Run: `cd web && npx vitest run lib/admin/edge-functions.test.ts` (fails, then passes after implementing in `web/lib/admin/edge-functions.ts`, reading `NEXT_PUBLIC_SUPABASE_URL`/anon key from `getSupabasePublicEnv()`).

- [ ] **Step 5: Write the migration `app/supabase/migrations/20261106130000_admin_customer_detail.sql`**

Follow the exact pattern of `get_admin_customer_referrer` in `20251007100000_feature_gates_staff_onboarding_analytics.sql` (plpgsql, `security definer`, `set search_path = public`, `perform public.assert_admin_access();` first line) for both `get_admin_customer_orders` and `get_admin_customer_reward_transactions`, selecting from `orders` (joined to `stores` for `store_name`) and `reward_transactions` respectively, filtered by `profile_id = p_customer_id`, ordered `created_at desc`, `limit greatest(1, least(p_limit, 100))`.

- [ ] **Step 6: Apply migration locally and verify by hand**

Run: `cd app && supabase db reset`, then call both RPCs for a seeded customer id via local Studio/SQL editor; confirm rows match that customer's seeded orders/reward transactions.

- [ ] **Step 7: Implement `web/app/admin/customers/actions.ts`**

Server Actions `disableCustomer(userId: string)` / `enableCustomer(userId: string)`: `requireAdmin()` → `assertNotSelf(userId, admin.userId)` → `const supabase = await createServerSupabaseClient()` → get the session access token (`supabase.auth.getSession()`) → `callAdminEdgeFunction("admin-customers", { action: "disable" | "enable", userId }, token)` → `logAdminAction(supabase, { action: "customer.disable" | "customer.enable", entityType: "customer", entityId: userId })` → `revalidatePath` the customer list/detail routes.

- [ ] **Step 8: Implement `web/app/admin/customers/page.tsx` and `web/app/admin/customers/[id]/page.tsx`**

List page: `requireAdmin()`, call `list_customers()` via the session client, render a table (name, email, points balance, active status, created date) with search-by-name/email client-side filtering and a link to each detail page. Detail page: `requireAdmin()`, fetch the customer row plus `get_admin_customer_orders` / `get_admin_customer_reward_transactions`, render profile details, order history, reward transaction history, and an enable/disable button wired to the Task 7 actions.

- [ ] **Step 9: Manual verification**

As admin: visit `/admin/customers`, confirm the seeded customers list with search working. Open a customer detail page, confirm order + reward history render (or an empty state if none). Disable the customer, confirm `is_active` flips, the customer can no longer sign in, and a `customer.disable` row appears in `admin_audit_log`. Re-enable, confirm reversed. Attempt to disable your own logged-in admin account by URL-hacking the action — confirm it's rejected with the self-lockout message before any edge function call.

- [ ] **Step 10: Commit**

```bash
git -C app add supabase/migrations/20261106130000_admin_customer_detail.sql
git -C app commit -m "feat: add admin customer order and reward history RPCs"
git -C web add lib/admin/edge-functions.ts lib/admin/edge-functions.test.ts lib/admin/self-action-guard.ts lib/admin/self-action-guard.test.ts app/admin/customers
git -C web commit -m "feat: add admin customer management"
```

---

## Task 6: Staff management

**Files:**
- Create: `web/app/admin/staff/page.tsx`
- Create: `web/app/admin/staff/new/page.tsx`
- Create: `web/app/admin/staff/[id]/page.tsx`
- Create: `web/app/admin/staff/actions.ts`

**Interfaces:**
- Consumes: `requireAdmin()`, `createServerSupabaseClient()`, `logAdminAction()`, `assertNotSelf()`, `callAdminEdgeFunction()` (Tasks 1, 4, 5).

- [ ] **Step 1: Implement `web/app/admin/staff/actions.ts`**

Server Actions:
- `createStaff(input: { name: string; email: string; role: "staff" | "admin"; storeId: string })`: `requireAdmin()` → `const supabase = await createServerSupabaseClient()` → get access token → `callAdminEdgeFunction("admin-staff", { action: "create", ...input }, token)` → `logAdminAction(supabase, { action: "staff.create", entityType: "staff", entityId: result.userId, metadata: { email: input.email, role: input.role } })` → return `{ email, temporaryPassword }` to the caller (shown once in the UI) → `revalidatePath("/admin/staff")`.
- `disableStaff(userId: string)` / `enableStaff(userId: string)`: same shape as the customer actions in Task 5 (`assertNotSelf` → edge function → audit log → revalidate), action names `"staff.disable"` / `"staff.enable"`.

- [ ] **Step 2: Implement `web/app/admin/staff/page.tsx`**

`requireAdmin()`, call `list_staff_members()` via the session client, render a table (name, email, role, assigned store, active status) with a link to `/admin/staff/new` and each row's detail page.

- [ ] **Step 3: Implement `web/app/admin/staff/new/page.tsx`**

Form (name, email, role select, store select) calling `createStaff`. Store options come from a direct `supabase.from("stores").select("id, name").eq("is_active", true)` query via the session client (read-only, not sensitive — `stores` is already broadly readable). On success, show the returned `temporaryPassword` once with a copy button and a note that it won't be shown again.

- [ ] **Step 4: Implement `web/app/admin/staff/[id]/page.tsx`**

Detail view (profile fields, assigned store, role) with enable/disable button wired to Task 1's actions.

- [ ] **Step 5: Manual verification**

As admin: visit `/admin/staff`, confirm the list. Create a new staff member, confirm the temporary password is shown once and an audit log entry appears. Attempt to create one with an email that already exists — confirm the edge function's error ("already been registered" or similar) renders in the form, not a crash. Disable/enable a staff member, confirm it's reflected and logged. Confirm disabling your own admin account is rejected the same way as Task 5.

- [ ] **Step 6: Commit**

```bash
git -C web add app/admin/staff
git -C web commit -m "feat: add admin staff management"
```

---

## Task 7: Overview / growth dashboard

**Files:**
- Create: `app/supabase/migrations/20261106140000_admin_growth_analytics.sql`
- Create: `web/lib/admin/growth-chart.ts`
- Test: `web/lib/admin/growth-chart.test.ts`
- Create: `web/app/admin/page.tsx`
- Modify: `web/package.json` (add `recharts` dependency)

**Interfaces:**
- Produces (SQL): `get_admin_growth_analytics(p_days integer default 30)` returns rows `(day date, new_customers integer, new_staff integer)`, one row per day in the trailing `p_days` days (zero-filled for days with no signups), `security definer`, `assert_admin_access()`.
- Produces (TS): `toGrowthChartSeries(rows: { day: string; new_customers: number; new_staff: number }[]): { date: string; customers: number; staff: number }[]` — pure mapping/renaming, same order as input.
- Consumes: `requireAdmin()`, `createServerSupabaseClient()` (Task 1); `get_admin_onboarding_analytics()` (existing RPC) for totals.

- [ ] **Step 1: Write the migration `app/supabase/migrations/20261106140000_admin_growth_analytics.sql`**

```sql
create or replace function public.get_admin_growth_analytics(p_days integer default 30)
returns table (
  day date,
  new_customers integer,
  new_staff integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  return query
  with days as (
    select generate_series(
      (current_date - (greatest(1, least(p_days, 365)) - 1)),
      current_date,
      interval '1 day'
    )::date as day
  )
  select
    d.day,
    count(*) filter (where p.staff_role is null)::integer as new_customers,
    count(*) filter (where p.staff_role is not null)::integer as new_staff
  from days d
  left join public.profiles p on p.created_at::date = d.day
  group by d.day
  order by d.day;
end;
$$;

grant execute on function public.get_admin_growth_analytics(integer) to authenticated, service_role;
```

- [ ] **Step 2: Apply migration locally and verify by hand**

Run: `cd app && supabase db reset`, call `select * from public.get_admin_growth_analytics(7);` as an admin; confirm 7 rows, one per day, zero-filled where there were no signups that day.

- [ ] **Step 3: Write the failing test for `toGrowthChartSeries`**

```ts
import { describe, it, expect } from "vitest";
import { toGrowthChartSeries } from "./growth-chart";

describe("toGrowthChartSeries", () => {
  it("maps snake_case RPC rows to chart-ready series, preserving order", () => {
    expect(
      toGrowthChartSeries([
        { day: "2026-11-01", new_customers: 3, new_staff: 0 },
        { day: "2026-11-02", new_customers: 1, new_staff: 1 },
      ]),
    ).toEqual([
      { date: "2026-11-01", customers: 3, staff: 0 },
      { date: "2026-11-02", customers: 1, staff: 1 },
    ]);
  });
});
```

- [ ] **Step 4: Run test to verify it fails; implement `toGrowthChartSeries` in `web/lib/admin/growth-chart.ts`; run again to verify it passes**

Run: `cd web && npx vitest run lib/admin/growth-chart.test.ts`

- [ ] **Step 5: Install `recharts` and implement `web/app/admin/page.tsx`**

Run: `npm install recharts --prefix web`. Page: `requireAdmin()`, call `get_admin_onboarding_analytics()` for totals (customers/staff/admins/staff-onboarded cards) and `get_admin_growth_analytics(30)` → `toGrowthChartSeries` for a line chart (customers vs. staff signups per day) using `recharts`.

- [ ] **Step 6: Manual verification**

Visit `/admin`, confirm totals cards match `list_customers()`/`list_staff_members()` counts, confirm the chart renders 30 days of data.

- [ ] **Step 7: Commit**

```bash
git -C app add supabase/migrations/20261106140000_admin_growth_analytics.sql
git -C app commit -m "feat: add admin growth analytics RPC"
git -C web add lib/admin/growth-chart.ts lib/admin/growth-chart.test.ts app/admin/page.tsx package.json package-lock.json
git -C web commit -m "feat: add admin overview dashboard"
```

---

## Task 8: Audit log viewer

**Files:**
- Create: `web/lib/admin/audit-log-pagination.ts`
- Test: `web/lib/admin/audit-log-pagination.test.ts`
- Create: `web/app/admin/audit-log/page.tsx`

**Interfaces:**
- Consumes: `list_admin_audit_log()` RPC (Task 4), `requireAdmin()` (Task 1).
- Produces: `nextAuditLogCursor(rows: { created_at: string }[]): string | null` — returns the `created_at` of the last row (for the next page's `p_before`), or `null` if `rows` is empty.

- [ ] **Step 1: Write the failing test for `nextAuditLogCursor`**

```ts
import { describe, it, expect } from "vitest";
import { nextAuditLogCursor } from "./audit-log-pagination";

describe("nextAuditLogCursor", () => {
  it("returns null for an empty page", () => {
    expect(nextAuditLogCursor([])).toBeNull();
  });

  it("returns the created_at of the last row", () => {
    expect(
      nextAuditLogCursor([
        { created_at: "2026-11-06T10:00:00Z" },
        { created_at: "2026-11-06T09:00:00Z" },
      ]),
    ).toBe("2026-11-06T09:00:00Z");
  });
});
```

- [ ] **Step 2: Run test to verify it fails; implement `nextAuditLogCursor` in `web/lib/admin/audit-log-pagination.ts`; run again to verify it passes**

Run: `cd web && npx vitest run lib/admin/audit-log-pagination.test.ts`

- [ ] **Step 3: Implement `web/app/admin/audit-log/page.tsx`**

`requireAdmin()`, accept a `before` search param, call `list_admin_audit_log(50, before ?? null)` via the session client, render a table (timestamp, actor email, action, entity type/id, metadata as collapsed JSON), with a "load more" link to the same page using `nextAuditLogCursor(rows)` as the next `before` value.

- [ ] **Step 4: Manual verification**

Having performed customer/staff disable/enable/create actions in Tasks 5–6, visit `/admin/audit-log`; confirm each prior action shows with correct actor email, action name, entity type/id, and timestamp, newest first. Confirm "load more" advances to older entries once there are more than 50 (or verify the cursor logic manually with a smaller seeded set if 50 isn't practical).

- [ ] **Step 5: Commit**

```bash
git -C web add lib/admin/audit-log-pagination.ts lib/admin/audit-log-pagination.test.ts app/admin/audit-log
git -C web commit -m "feat: add admin audit log viewer"
```
