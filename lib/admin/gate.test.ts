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
