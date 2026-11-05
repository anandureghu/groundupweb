import { describe, it, expect } from "vitest";
import { nextAuditLogCursor } from "./audit-log-pagination";

describe("nextAuditLogCursor", () => {
  it("returns null for an empty page", () => {
    expect(nextAuditLogCursor([])).toBeNull();
  });

  it("returns the created_at of the last row", () => {
    expect(
      nextAuditLogCursor([
        { created_at: "2026-11-06T10:00:00Z" },
        { created_at: "2026-11-06T09:00:00Z" },
      ]),
    ).toBe("2026-11-06T09:00:00Z");
  });
});
