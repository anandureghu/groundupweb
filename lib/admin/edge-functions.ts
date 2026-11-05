import { getSupabasePublicEnv } from "@/lib/supabase/env";

export type AdminEdgeFunctionName = "admin-customers" | "admin-staff";

export async function callAdminEdgeFunction<T>(
  name: AdminEdgeFunctionName,
  payload: object,
  accessToken: string,
): Promise<T> {
  const { url, key } = getSupabasePublicEnv();

  const response = await fetch(`${url}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
      apikey: key,
    },
    body: JSON.stringify(payload),
  });

  const body = await response.json();

  if (!response.ok) {
    throw new Error(body?.error ?? "Request failed.");
  }

  return body as T;
}
