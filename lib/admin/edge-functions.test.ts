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
