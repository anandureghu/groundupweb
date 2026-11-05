export type AdminSession = { userId: string } | null;
export type AdminProfile = { staffRole: string | null } | null;
export type AdminGateResult = "allow" | "login" | "unauthorized";

export function resolveAdminGateResult(
  session: AdminSession,
  profile: AdminProfile,
): AdminGateResult {
  if (!session) {
    return "login";
  }

  if (!profile) {
    return "unauthorized";
  }

  if (profile.staffRole !== "admin") {
    return "unauthorized";
  }

  return "allow";
}
