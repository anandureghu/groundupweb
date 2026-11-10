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
import { challengeGoalLabel, challengeTypeLabel } from "@/lib/admin/challenges";
import { rowsOf } from "@/lib/admin/notifications";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "Challenges",
};

type ChallengeRpcRow = {
  id: string;
  name: string;
  slug: string;
  type: string;
  target_count: number;
  daily_step_target: number | null;
  reward_points: number;
  is_active: boolean;
  participant_count: number;
  completed_count: number;
};

export default async function AdminChallengesPage() {
  await requireAdmin();
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("admin_list_challenges");

  if (error) {
    console.error("admin_list_challenges failed", error);
  }

  const challenges = rowsOf<ChallengeRpcRow>(data);

  return (
    <div className="flex flex-col gap-6">
      <AdminPageHeader
        title="Challenges"
        description="See who has started each challenge and how far they have got."
      />

      {error ? (
        <p className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error.message}
        </p>
      ) : null}

      {challenges.length === 0 && !error ? (
        <p className="text-sm text-zinc-500">No challenges yet.</p>
      ) : (
        <AdminTable>
          <AdminTableHead>
            <tr>
              <AdminTh>Challenge</AdminTh>
              <AdminTh>Type</AdminTh>
              <AdminTh>Goal</AdminTh>
              <AdminTh>Participating</AdminTh>
              <AdminTh>Completed</AdminTh>
              <AdminTh>Status</AdminTh>
            </tr>
          </AdminTableHead>
          <tbody>
            {challenges.map((challenge) => (
              <tr key={challenge.id} className="border-b border-zinc-100 last:border-b-0">
                <AdminTd>
                  <Link
                    href={`/admin/challenges/${challenge.id}`}
                    className="font-medium text-zinc-900 underline-offset-2 hover:underline"
                  >
                    {challenge.name}
                  </Link>
                  <p className="text-xs text-zinc-500">{challenge.reward_points} points</p>
                </AdminTd>
                <AdminTd>{challengeTypeLabel(challenge.type)}</AdminTd>
                <AdminTd>
                  {challengeGoalLabel({
                    type: challenge.type,
                    targetCount: challenge.target_count,
                    dailyStepTarget: challenge.daily_step_target,
                  })}
                </AdminTd>
                <AdminTd>{challenge.participant_count}</AdminTd>
                <AdminTd>{challenge.completed_count}</AdminTd>
                <AdminTd>
                  <AdminStatusPill active={challenge.is_active} inactiveLabel="Archived" />
                </AdminTd>
              </tr>
            ))}
          </tbody>
        </AdminTable>
      )}
    </div>
  );
}
