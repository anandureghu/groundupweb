import { requireAdmin } from "@/lib/admin/auth";
import { AdminNav } from "@/components/admin/admin-nav";

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { email } = await requireAdmin();

  return (
    <div className="flex h-dvh w-full overflow-hidden bg-zinc-100 text-zinc-900">
      <AdminNav email={email} />
      <main className="min-h-0 min-w-0 flex-1 overflow-y-auto">
        <div className="mx-auto w-full max-w-6xl px-6 py-8 sm:px-8">
          {children}
        </div>
      </main>
    </div>
  );
}
