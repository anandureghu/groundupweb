import { describe, it, expect, vi } from "vitest";
import { toAuditLogRpcArgs, logAdminAction } from "./audit-log";

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
