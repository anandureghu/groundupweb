"use server";

import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase/server";

export type SignInAdminState = { error: string } | null;

export async function signInAdmin(
  _prevState: SignInAdminState,
  formData: FormData,
): Promise<SignInAdminState> {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");

  const supabase = await createServerSupabaseClient();

  const { data: signInData, error: signInError } =
    await supabase.auth.signInWithPassword({ email, password });

  if (signInError || !signInData.user) {
    return { error: "Incorrect email or password." };
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("staff_role")
    .eq("id", signInData.user.id)
    .maybeSingle();

  if (profile?.staff_role !== "admin") {
    await supabase.auth.signOut();
    return { error: "This account does not have admin access." };
  }

  redirect("/admin");
}
