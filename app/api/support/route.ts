import { NextResponse } from "next/server";

import {
  SUPPORT_TOPICS,
  type SupportTopic,
} from "@/content/support-faq";
import { createAdminClient } from "@/lib/supabase/admin";
import { isSupabaseConfigured } from "@/lib/supabase/env";

interface SupportRequestBody {
  name?: string;
  email?: string;
  topic?: string;
  message?: string;
  website?: string;
}

const TOPIC_VALUES = new Set(SUPPORT_TOPICS.map((topic) => topic.value));

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/** Always succeed from the client's perspective. */
function ok() {
  return NextResponse.json({ ok: true });
}

export async function POST(request: Request) {
  let body: SupportRequestBody;

  try {
    body = (await request.json()) as SupportRequestBody;
  } catch {
    return ok();
  }

  // Honeypot — bots fill hidden fields; humans leave this empty.
  if (body.website?.trim()) {
    return ok();
  }

  const name = body.name?.trim() ?? "";
  const email = body.email?.trim().toLowerCase() ?? "";
  const topic = (body.topic?.trim() ?? "") as SupportTopic;
  const message = body.message?.trim() ?? "";

  if (
    name.length < 2 ||
    !isValidEmail(email) ||
    !TOPIC_VALUES.has(topic) ||
    message.length < 20 ||
    message.length > 4000
  ) {
    return ok();
  }

  if (!isSupabaseConfigured() || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    console.error("[support] Supabase is not configured; request not saved.");
    return ok();
  }

  try {
    const supabase = createAdminClient();
    const userAgent = request.headers.get("user-agent")?.slice(0, 500) ?? null;

    const { error } = await supabase.from("support_requests").insert({
      name,
      email,
      topic,
      message,
      status: "new",
      source: "web",
      user_agent: userAgent,
    });

    if (error) {
      console.error("[support] insert failed", error);
    }
  } catch (error) {
    console.error("[support]", error);
  }

  return ok();
}
