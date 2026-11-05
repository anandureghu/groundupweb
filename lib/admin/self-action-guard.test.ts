import { describe, it, expect } from "vitest";
import { assertNotSelf } from "./self-action-guard";

describe("assertNotSelf", () => {
  it("throws when target and actor are the same user", () => {
    expect(() => assertNotSelf("u1", "u1")).toThrow(
      "You can't do this to your own account.",
    );
  });

  it("does not throw for different users", () => {
    expect(() => assertNotSelf("u1", "u2")).not.toThrow();
  });
});
