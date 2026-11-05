export function assertNotSelf(targetUserId: string, actingUserId: string): void {
  if (targetUserId === actingUserId) {
    throw new Error("You can't do this to your own account.");
  }
}
