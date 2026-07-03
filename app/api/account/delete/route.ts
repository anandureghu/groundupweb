import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { isSupabaseConfigured } from "@/lib/supabase/env";
import { verifyUserCredentials } from "@/lib/supabase/verify-credentials";

interface DeleteAccountRequest {
  email?: string;
  password?: string;
  reason?: string;
  experienceRating?: number | null;
  experienceEmoji?: string | null;
}

function mapDeletionError(message: string) {
  const normalized = message.toLowerCase();

  if (normalized.includes("no account found")) {
    return "No account was found for this email address.";
  }

  if (normalized.includes("already been deleted")) {
    return "This account has already been deleted.";
  }

  if (normalized.includes("staff accounts")) {
    return "This account cannot be deleted from this page.";
  }

  if (normalized.includes("email is required")) {
    return "Email is required.";
  }

  if (normalized.includes("reason is required")) {
    return "Please tell us why you are deleting your account.";
  }

  return message;
}

export async function POST(request: Request) {
  if (!isSupabaseConfigured()) {
    return NextResponse.json(
      { error: "Account deletion is not configured yet." },
      { status: 503 },
    );
  }

  let body: DeleteAccountRequest;

  try {
    body = (await request.json()) as DeleteAccountRequest;
  } catch {
    return NextResponse.json({ error: "Invalid request body." }, { status: 400 });
  }

  const email = body.email?.trim() ?? "";
  const password = body.password ?? "";
  const reason = body.reason?.trim() ?? "";
  const experienceRating =
    typeof body.experienceRating === "number" ? body.experienceRating : null;
  const experienceEmoji = body.experienceEmoji?.trim() ?? null;

  if (!email) {
    return NextResponse.json({ error: "Email is required." }, { status: 400 });
  }

  if (!password) {
    return NextResponse.json({ error: "Password is required." }, { status: 400 });
  }

  if (!reason || reason.length < 10) {
    return NextResponse.json(
      { error: "Please provide a reason with at least 10 characters." },
      { status: 400 },
    );
  }

  if (
    experienceRating !== null &&
    (!Number.isInteger(experienceRating) ||
      experienceRating < 1 ||
      experienceRating > 5)
  ) {
    return NextResponse.json(
      { error: "Experience rating must be between 1 and 5." },
      { status: 400 },
    );
  }

  try {
    const verification = await verifyUserCredentials(email, password);

    if (!verification.ok) {
      return NextResponse.json(
        { error: "Incorrect email or password." },
        { status: 401 },
      );
    }

    const admin = createAdminClient();

    const { data: profileId, error: rpcError } = await admin.rpc(
      "delete_member_account",
      {
        p_email: email,
        p_reason: reason,
        p_experience_rating: experienceRating,
        p_experience_emoji: experienceEmoji,
      },
    );

    if (rpcError) {
      return NextResponse.json(
        { error: mapDeletionError(rpcError.message) },
        { status: 400 },
      );
    }

    if (!profileId) {
      return NextResponse.json(
        { error: "Unable to delete account." },
        { status: 500 },
      );
    }

    if (profileId !== verification.userId) {
      return NextResponse.json(
        { error: "Unable to verify account ownership." },
        { status: 403 },
      );
    }

    const { error: authError } = await admin.auth.admin.deleteUser(profileId);

    if (authError) {
      return NextResponse.json(
        { error: "Account data was anonymized but sign-in could not be removed. Please contact support." },
        { status: 500 },
      );
    }

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "Unable to delete account.",
      },
      { status: 500 },
    );
  }
}
