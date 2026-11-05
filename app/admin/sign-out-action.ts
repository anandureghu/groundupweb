"use server";

import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase/server";

export async function signOutAdmin(): Promise<void> {
  const supabase = await createServerSupabaseClient();

  await supabase.auth.signOut();

  redirect("/admin/login");
}
