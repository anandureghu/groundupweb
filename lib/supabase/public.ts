import { createClient } from "@supabase/supabase-js";

import { getSupabasePublicEnv, isSupabaseConfigured } from "./env";

export type PublicFeatureGates = {
  defaultMode: "coming_soon" | "full";
  comingSoonMessage: string;
};

const DEFAULT_GATES: PublicFeatureGates = {
  defaultMode: "coming_soon",
  comingSoonMessage:
    "We are preparing something special. Check back soon.",
};

export function createPublicSupabaseClient() {
  const { url, key } = getSupabasePublicEnv();
  return createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

export async function getPublicFeatureGates(): Promise<PublicFeatureGates> {
  if (!isSupabaseConfigured()) {
    return DEFAULT_GATES;
  }

  try {
    const supabase = createPublicSupabaseClient();
    const { data, error } = await supabase.rpc("get_public_feature_gates");

    if (error) {
      console.error("get_public_feature_gates failed", error.message);
      return DEFAULT_GATES;
    }

    const row = Array.isArray(data) ? data[0] : data;
    if (!row) {
      return DEFAULT_GATES;
    }

    const mode =
      row.default_mode === "full" ? "full" : "coming_soon";

    return {
      defaultMode: mode,
      comingSoonMessage:
        String(row.coming_soon_message ?? "").trim() ||
        DEFAULT_GATES.comingSoonMessage,
    };
  } catch (error) {
    console.error("getPublicFeatureGates error", error);
    return DEFAULT_GATES;
  }
}

export function getStoreUrls() {
  return {
    ios: process.env.NEXT_PUBLIC_IOS_STORE_URL?.trim() || "",
    android: process.env.NEXT_PUBLIC_ANDROID_STORE_URL?.trim() || "",
  };
}
