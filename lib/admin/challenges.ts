const CHALLENGE_TYPE_LABELS: Record<string, string> = {
  step_streak: "Walking streak",
  step_total: "Step total",
  purchase_count: "Purchases",
  login_streak: "Login streak",
};

export function challengeTypeLabel(type: string): string {
  return CHALLENGE_TYPE_LABELS[type] ?? type;
}

export function challengeGoalLabel(input: {
  type: string;
  targetCount: number;
  dailyStepTarget: number | null;
}): string {
  if (input.type === "step_streak" && input.dailyStepTarget) {
    return `${input.targetCount} days at ${input.dailyStepTarget.toLocaleString()} steps`;
  }
  if (input.type === "step_total") {
    return `${input.targetCount.toLocaleString()} steps`;
  }
  if (input.type === "purchase_count") {
    return `${input.targetCount} purchases`;
  }
  if (input.type === "login_streak") {
    return `${input.targetCount} days in a row`;
  }
  return String(input.targetCount);
}

export function participantStatus(input: {
  currentCount: number;
  targetCount: number;
  completedAt: string | null;
  rewardedAt: string | null;
}): "Rewarded" | "Completed" | "In progress" {
  if (input.rewardedAt) {
    return "Rewarded";
  }
  if (input.completedAt || input.currentCount >= input.targetCount) {
    return "Completed";
  }
  return "In progress";
}
