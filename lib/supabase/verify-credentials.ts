import { createClient } from "@supabase/supabase-js";
import { getSupabasePublicEnv } from "./env";

export async function verifyUserCredentials(email: string, password: string) {
  const { url, key } = getSupabasePublicEnv();
  const supabase = createClient(url, key, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error || !data.user) {
    return { ok: false as const, userId: null };
  }

  return { ok: true as const, userId: data.user.id };
}
