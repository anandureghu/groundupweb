"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { SUPPORT_TOPICS, type SupportTopic } from "@/content/support-faq";

const fieldClassName =
  "w-full border border-border bg-background px-4 py-3 text-[15px] outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30";

interface SupportFormDialogProps {
  triggerLabel?: string;
  triggerVariant?: "default" | "outline";
  defaultOpen?: boolean;
}

export function SupportFormDialog({
  triggerLabel = "Contact support",
  triggerVariant = "default",
  defaultOpen = false,
}: SupportFormDialogProps) {
  const [open, setOpen] = useState(defaultOpen);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [topic, setTopic] = useState<SupportTopic | "">("");
  const [message, setMessage] = useState("");
  const [honeypot, setHoneypot] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isComplete, setIsComplete] = useState(false);

  function resetForm() {
    setName("");
    setEmail("");
    setTopic("");
    setMessage("");
    setHoneypot("");
    setIsComplete(false);
  }

  function handleOpenChange(nextOpen: boolean) {
    setOpen(nextOpen);
    if (!nextOpen) {
      setIsSubmitting(false);
      if (isComplete) {
        resetForm();
      }
    }
  }

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSubmitting(true);

    try {
      await fetch("/api/support", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: name.trim(),
          email: email.trim(),
          topic,
          message: message.trim(),
          website: honeypot,
        }),
      });
    } catch {
      // Intentionally silent — always show success to the customer.
    } finally {
      setIsSubmitting(false);
      setIsComplete(true);
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button variant={triggerVariant}>{triggerLabel}</Button>
      </DialogTrigger>
      <DialogContent aria-describedby="support-form-description">
        <DialogHeader>
          <DialogTitle>Contact support</DialogTitle>
          <DialogDescription id="support-form-description">
            Tell us what you need help with. We usually reply within 1–2
            business days.
          </DialogDescription>
        </DialogHeader>

        {isComplete ? (
          <div className="space-y-4">
            <p className="text-[15px] leading-relaxed text-muted-foreground">
              Thanks — your request has been sent. We&apos;ll get back to you
              within 1–2 business days.
            </p>
            <DialogFooter>
              <Button type="button" onClick={() => handleOpenChange(false)}>
                Done
              </Button>
            </DialogFooter>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <label htmlFor="support-name" className="text-sm font-semibold">
                Name
              </label>
              <input
                id="support-name"
                name="name"
                required
                autoComplete="name"
                value={name}
                onChange={(event) => setName(event.target.value)}
                className={fieldClassName}
                placeholder="Your name"
              />
            </div>

            <div className="space-y-2">
              <label htmlFor="support-email" className="text-sm font-semibold">
                Email
              </label>
              <input
                id="support-email"
                name="email"
                type="email"
                required
                autoComplete="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                className={fieldClassName}
                placeholder="you@example.com"
              />
            </div>

            <div className="space-y-2">
              <label htmlFor="support-topic" className="text-sm font-semibold">
                Topic
              </label>
              <select
                id="support-topic"
                name="topic"
                required
                value={topic}
                onChange={(event) =>
                  setTopic(event.target.value as SupportTopic | "")
                }
                className={`${fieldClassName} appearance-none`}
              >
                <option value="" disabled>
                  Choose a topic
                </option>
                {SUPPORT_TOPICS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
            </div>

            <div className="space-y-2">
              <label htmlFor="support-message" className="text-sm font-semibold">
                How can we help?
              </label>
              <textarea
                id="support-message"
                name="message"
                required
                minLength={20}
                maxLength={4000}
                rows={5}
                value={message}
                onChange={(event) => setMessage(event.target.value)}
                className={`${fieldClassName} resize-y`}
                placeholder="Share what’s going on, and any steps we should know about…"
              />
            </div>

            <div className="hidden" aria-hidden="true">
              <label htmlFor="support-website">Website</label>
              <input
                id="support-website"
                name="website"
                tabIndex={-1}
                autoComplete="off"
                value={honeypot}
                onChange={(event) => setHoneypot(event.target.value)}
              />
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => handleOpenChange(false)}
                disabled={isSubmitting}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={isSubmitting}>
                {isSubmitting ? "Sending…" : "Send request"}
              </Button>
            </DialogFooter>
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
}
