"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";

const EXPERIENCE_OPTIONS = [
  { emoji: "😞", label: "Very poor" },
  { emoji: "😕", label: "Poor" },
  { emoji: "😐", label: "Okay" },
  { emoji: "🙂", label: "Good" },
  { emoji: "😍", label: "Excellent" },
] as const;

interface DeleteAccountFormProps {
  initialEmail?: string;
}

export function DeleteAccountForm({ initialEmail = "" }: DeleteAccountFormProps) {
  const [email, setEmail] = useState(initialEmail);
  const [password, setPassword] = useState("");
  const [reason, setReason] = useState("");
  const [experienceIndex, setExperienceIndex] = useState<number | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isComplete, setIsComplete] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setIsSubmitting(true);

    try {
      const selected =
        experienceIndex !== null
          ? EXPERIENCE_OPTIONS[experienceIndex]
          : undefined;
      const experienceRating =
        experienceIndex !== null ? experienceIndex + 1 : null;

      const response = await fetch("/api/account/delete", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: email.trim(),
          password,
          reason: reason.trim(),
          experienceRating,
          experienceEmoji: selected?.emoji ?? null,
        }),
      });

      const payload = (await response.json()) as {
        error?: string;
      };

      if (!response.ok) {
        throw new Error(payload.error ?? "Unable to delete account");
      }

      setIsComplete(true);
    } catch (submitError) {
      setError(
        submitError instanceof Error
          ? submitError.message
          : "Unable to delete account",
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  if (isComplete) {
    return (
      <div className="space-y-4 rounded-lg border border-border bg-muted/30 p-6 text-center">
        <h2 className="text-xl font-semibold">Account deleted</h2>
        <p className="text-[15px] leading-relaxed text-muted-foreground">
          Your account has been permanently deleted. You will no longer be able
          to sign in with this email address.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="space-y-2">
        <label htmlFor="email" className="text-sm font-semibold">
          Email address
        </label>
        <input
          id="email"
          name="email"
          type="email"
          required
          autoComplete="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          className="w-full border border-border bg-background px-4 py-3 text-[15px] outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
          placeholder="you@example.com"
        />
      </div>

      <div className="space-y-2">
        <label htmlFor="password" className="text-sm font-semibold">
          Password
        </label>
        <input
          id="password"
          name="password"
          type="password"
          required
          autoComplete="current-password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          className="w-full border border-border bg-background px-4 py-3 text-[15px] outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
          placeholder="Enter your account password"
        />
        <p className="text-[13px] text-muted-foreground">
          We need to verify your identity before deleting your account.
        </p>
      </div>

      <div className="space-y-2">
        <label htmlFor="reason" className="text-sm font-semibold">
          Why are you deleting your account?
        </label>
        <textarea
          id="reason"
          name="reason"
          required
          minLength={10}
          rows={4}
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          className="w-full resize-y border border-border bg-background px-4 py-3 text-[15px] outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
          placeholder="Tell us why you are leaving..."
        />
      </div>

      <fieldset className="space-y-3">
        <legend className="text-sm font-semibold">
          How was your experience? (optional)
        </legend>
        <div className="flex flex-wrap gap-3">
          {EXPERIENCE_OPTIONS.map((option, index) => {
            const isSelected = experienceIndex === index;

            return (
              <button
                key={index}
                type="button"
                aria-label={option.label}
                aria-pressed={isSelected}
                onClick={() =>
                  setExperienceIndex((current) =>
                    current === index ? null : index,
                  )
                }
                className={`flex min-w-[4.5rem] flex-col items-center gap-1 border px-3 py-3 text-center transition-colors ${
                  isSelected
                    ? "border-foreground bg-muted"
                    : "border-border hover:bg-muted/50"
                }`}
              >
                <span className="text-2xl">{option.emoji}</span>
                <span className="text-[11px] tracking-wide text-muted-foreground uppercase">
                  {option.label}
                </span>
              </button>
            );
          })}
        </div>
      </fieldset>

      {error && (
        <p className="text-sm text-destructive" role="alert">
          {error}
        </p>
      )}

      <Button
        type="submit"
        variant="destructive"
        className="w-full"
        disabled={isSubmitting}
      >
        {isSubmitting ? "Deleting account..." : "Delete account permanently"}
      </Button>
    </form>
  );
}
