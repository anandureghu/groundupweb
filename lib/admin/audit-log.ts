import type { SupabaseClient } from "@supabase/supabase-js";

export function toAuditLogRpcArgs(input: {
  action: string;
  entityType: string;
  entityId?: string;
  metadata?: Record<string, unknown>;
}): {
  p_action: string;
  p_entity_type: string;
  p_entity_id: string | null;
  p_metadata: Record<string, unknown>;
} {
  return {
    p_action: input.action,
    p_entity_type: input.entityType,
    p_entity_id: input.entityId ?? null,
    p_metadata: input.metadata ?? {},
  };
}

export async function logAdminAction(
  client: Pick<SupabaseClient, "rpc">,
  input: {
    action: string;
    entityType: string;
    entityId?: string;
    metadata?: Record<string, unknown>;
  },
): Promise<void> {
  const { error } = await client.rpc(
    "log_admin_action",
    toAuditLogRpcArgs(input),
  );

  if (error) {
    console.error("logAdminAction failed", error);
    return;
  }
}
