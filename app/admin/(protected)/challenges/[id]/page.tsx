import type { Metadata } from "next";
import Link from "next/link";

import {
  AdminPageHeader,
  AdminStatusPill,
  AdminTable,
  AdminTableHead,
  AdminTd,
  AdminTh,
} from "@/components/admin/admin-ui";
import { requireAdmin } from "@/lib/admin/auth";
import {
  challengeGoalLabel,
  challengeTypeLabel,
  participantStatus,
} from "@/lib/admin/challenges";
import { rowsOf } from "@/lib/admin/notifications";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "Challenge progress",
};

type ChallengeRpcRow = {
  id: string;
  name: string;
  type: string;
  description: string;
  target_count: number;
  daily_step_target: number | null;
  reward_points: number;
  is_active: boolean;
  participant_count: number;
  completed_count: number;
};

type ParticipantRpcRow = {
  profile_id: string;
  first_name: string | null;
  last_name: string | null;
  email: string | null;
  current_count: number;
  target_count: number;
  last_activity_date: string | null;
  completed_at: string | null;
  rewarded_at: string | null;
};

export default async function AdminChallengeDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireAdmin();
  const { id } = await params;
  const supabase = await createServerSupabaseClient();

  const [{ data: challenges, error: challengesError }, { data: participants, error: participantsError }] =
    await Promise.all([
      supabase.rpc("admin_list_challenges"),
      supabase.rpc("admin_list_challenge_participants", { p_challenge_id: id }),
    ]);

  const error = challengesError ?? participantsError;
  if (error) {
    console.error("admin challenge detail failed", error);
  }

  const challenge = rowsOf<ChallengeRpcRow>(challenges).find((row) => row.id === id);
  const rows = rowsOf<ParticipantRpcRow>(participants);

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title={challenge?.name ?? "Challenge"}
        description={
          challenge
            ? `${challengeTypeLabel(challenge.type)} · ${challengeGoalLabel({
                type: challenge.type,
                targetCount: challenge.target_count,
                dailyStepTarget: challenge.daily_step_target,
              })} · ${challenge.participant_count} participating, ${challenge.completed_count} completed`
            : "This challenge could not be loaded."
        }
        breadcrumb={{ href: "/admin/challenges", label: "Challenges" }}
        actions={
          challenge ? (
            <AdminStatusPill active={challenge.is_active} inactiveLabel="Archived" />
          ) : null
        }
      />

      {error ? (
        <p className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error.message}
        </p>
      ) : null}

      {!challenge && !error ? (
        <p className="text-sm text-zinc-500">
          Challenge not found.{" "}
          <Link href="/admin/challenges" className="underline">
            Back to challenges
          </Link>
        </p>
      ) : null}

      {challenge && rows.length === 0 && !error ? (
        <p className="text-sm text-zinc-500">No one has progress on this challenge yet.</p>
      ) : null}

      {rows.length > 0 ? (
        <AdminTable>
          <AdminTableHead>
            <tr>
              <AdminTh>Member</AdminTh>
              <AdminTh>Progress</AdminTh>
              <AdminTh>Last activity</AdminTh>
              <AdminTh>Status</AdminTh>
            </tr>
          </AdminTableHead>
          <tbody>
            {rows.map((row) => {
              const name = `${row.first_name ?? ""} ${row.last_name ?? ""}`.trim();
              const status = participantStatus({
                currentCount: row.current_count,
                targetCount: row.target_count,
                completedAt: row.completed_at,
                rewardedAt: row.rewarded_at,
              });
              return (
                <tr key={row.profile_id} className="border-b border-zinc-100 last:border-b-0">
                  <AdminTd>
                    <Link
                      href={`/admin/customers/${row.profile_id}`}
                      className="font-medium text-zinc-900 underline-offset-2 hover:underline"
                    >
                      {name || "Member"}
                    </Link>
                    <p className="text-xs text-zinc-500">{row.email}</p>
                  </AdminTd>
                  <AdminTd>
                    {row.current_count.toLocaleString()} / {row.target_count.toLocaleString()}
                  </AdminTd>
                  <AdminTd className="text-zinc-500">
                    {row.last_activity_date
                      ? new Date(`${row.last_activity_date}T12:00:00`).toLocaleDateString()
                      : "—"}
                  </AdminTd>
                  <AdminTd>
                    <AdminStatusPill
                      active={status !== "In progress"}
                      activeLabel={status}
                      inactiveLabel="In progress"
                    />
                  </AdminTd>
                </tr>
              );
            })}
          </tbody>
        </AdminTable>
      ) : null}
    </div>
  );
}
