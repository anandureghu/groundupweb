export function nextAuditLogCursor(
  rows: { created_at: string }[],
): string | null {
  if (rows.length === 0) {
    return null;
  }

  return rows[rows.length - 1].created_at;
}
