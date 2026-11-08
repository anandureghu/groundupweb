"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin } from "@/lib/admin/auth";
import { logAdminAction } from "@/lib/admin/audit-log";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export type ProductActionState = { error?: string; success?: string } | null;

function parseMoneyToCents(raw: string): number | null {
  const trimmed = raw.trim();
  if (!trimmed) {
    return null;
  }
  const value = Number(trimmed);
  if (!Number.isFinite(value) || value < 0) {
    return null;
  }
  return Math.round(value * 100);
}

function parseNonNegativeInt(raw: string, fallback: number | null = null) {
  const trimmed = raw.trim();
  if (!trimmed) {
    return fallback;
  }
  const value = Number(trimmed);
  if (!Number.isInteger(value) || value < 0) {
    return null;
  }
  return value;
}

export async function updateProduct(
  _prev: ProductActionState,
  formData: FormData,
): Promise<ProductActionState> {
  await requireAdmin();

  const id = String(formData.get("id") ?? "").trim();
  const name = String(formData.get("name") ?? "").trim();
  const slug = String(formData.get("slug") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const categoryId = String(formData.get("category_id") ?? "").trim();
  const imageUrl = String(formData.get("image_url") ?? "").trim();
  const badge = String(formData.get("badge") ?? "").trim();
  const isActive = formData.get("is_active") === "on";
  const isFeatured = formData.get("is_featured") === "on";
  const isSeasonal = formData.get("is_seasonal") === "on";
  const isRedeemable = formData.get("is_redeemable") === "on";
  const redeemTitle = String(formData.get("redeem_title") ?? "").trim();
  const redeemDescription = String(
    formData.get("redeem_description") ?? "",
  ).trim();

  if (!id) {
    return { error: "Product id is required." };
  }
  if (!name) {
    return { error: "Name is required." };
  }
  if (!slug) {
    return { error: "Slug is required." };
  }
  if (!categoryId) {
    return { error: "Category is required." };
  }

  const priceCents = parseMoneyToCents(
    String(formData.get("price_gbp") ?? ""),
  );
  if (priceCents === null) {
    return { error: "Base price must be a valid amount in GBP." };
  }

  const pointsEarned = parseNonNegativeInt(
    String(formData.get("points_earned") ?? ""),
    0,
  );
  if (pointsEarned === null) {
    return { error: "Legacy points earned must be a non-negative whole number." };
  }

  const pointsEarnedOverrideRaw = String(
    formData.get("points_earned_override") ?? "",
  ).trim();
  const pointsEarnedOverride =
    pointsEarnedOverrideRaw === ""
      ? null
      : parseNonNegativeInt(pointsEarnedOverrideRaw);
  if (pointsEarnedOverrideRaw !== "" && pointsEarnedOverride === null) {
    return {
      error: "Points earned override must be a non-negative whole number.",
    };
  }

  const pointsToRedeem = parseNonNegativeInt(
    String(formData.get("points_to_redeem") ?? ""),
    0,
  );
  if (pointsToRedeem === null) {
    return { error: "Points to redeem must be a non-negative whole number." };
  }
  if (isRedeemable && (pointsToRedeem ?? 0) <= 0) {
    return { error: "Redeemable products need points to redeem greater than 0." };
  }

  const variantIds = formData.getAll("variant_id").map((value) => String(value));
  const variantNames = formData
    .getAll("variant_name")
    .map((value) => String(value));
  const variantPrices = formData
    .getAll("variant_price_gbp")
    .map((value) => String(value));
  const variantSorts = formData
    .getAll("variant_sort_order")
    .map((value) => String(value));
  const variantActiveFlags = new Set(
    formData.getAll("variant_active").map((value) => String(value)),
  );

  if (
    variantIds.length !== variantNames.length ||
    variantIds.length !== variantPrices.length ||
    variantIds.length !== variantSorts.length
  ) {
    return { error: "Variant fields are incomplete." };
  }

  const variants: Array<{
    id: string | null;
    name: string;
    priceCents: number;
    sortOrder: number;
    isActive: boolean;
  }> = [];

  for (let index = 0; index < variantIds.length; index += 1) {
    const variantName = variantNames[index]?.trim() ?? "";
    const priceRaw = variantPrices[index] ?? "";
    const sortRaw = variantSorts[index] ?? "0";
    const variantId = variantIds[index]?.trim() || null;

    if (!variantName && !priceRaw.trim() && !variantId) {
      continue;
    }
    if (!variantName) {
      return { error: "Each size/variant needs a name." };
    }

    const variantPriceCents = parseMoneyToCents(priceRaw);
    if (variantPriceCents === null) {
      return { error: `Invalid price for variant “${variantName}”.` };
    }

    const sortOrder = parseNonNegativeInt(sortRaw, 0);
    if (sortOrder === null) {
      return { error: `Invalid sort order for variant “${variantName}”.` };
    }

    const activeKey = variantId ?? `new-${index}`;
    variants.push({
      id: variantId,
      name: variantName,
      priceCents: variantPriceCents,
      sortOrder: sortOrder ?? 0,
      isActive: variantActiveFlags.has(activeKey),
    });
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase
    .from("products")
    .update({
      name,
      slug,
      description: description || null,
      category_id: categoryId,
      price_cents: priceCents,
      image_url: imageUrl || null,
      badge: badge || null,
      is_active: isActive,
      is_featured: isFeatured,
      is_seasonal: isSeasonal,
      points_earned: pointsEarned,
      points_earned_override: pointsEarnedOverride,
      is_redeemable: isRedeemable,
      points_to_redeem: pointsToRedeem,
      redeem_title: redeemTitle || null,
      redeem_description: redeemDescription || null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", id);

  if (error) {
    return { error: error.message };
  }

  for (const variant of variants) {
    if (variant.id) {
      const { error: variantError } = await supabase
        .from("product_variants")
        .update({
          name: variant.name,
          price_cents: variant.priceCents,
          sort_order: variant.sortOrder,
          is_active: variant.isActive,
        })
        .eq("id", variant.id)
        .eq("product_id", id);

      if (variantError) {
        return { error: variantError.message };
      }
      continue;
    }

    const { error: insertError } = await supabase
      .from("product_variants")
      .insert({
        product_id: id,
        name: variant.name,
        price_cents: variant.priceCents,
        sort_order: variant.sortOrder,
        is_active: variant.isActive,
      });

    if (insertError) {
      return { error: insertError.message };
    }
  }

  await logAdminAction(supabase, {
    action: "product.update",
    entityType: "product",
    entityId: id,
    metadata: {
      name,
      isActive,
      isRedeemable,
      pointsToRedeem,
      variantCount: variants.length,
    },
  });

  revalidatePath("/admin/products");
  revalidatePath(`/admin/products/${id}`);
  return { success: "Product saved." };
}

export async function bulkSetProductsRedeemable(
  _prev: ProductActionState,
  formData: FormData,
): Promise<ProductActionState> {
  await requireAdmin();

  const pointsRaw = String(formData.get("points_to_redeem") ?? "250").trim();
  const pointsToRedeem = Number(pointsRaw);
  if (!Number.isInteger(pointsToRedeem) || pointsToRedeem <= 0) {
    return { error: "Points to redeem must be a positive whole number." };
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase
    .from("products")
    .update({
      is_redeemable: true,
      points_to_redeem: pointsToRedeem,
      updated_at: new Date().toISOString(),
    })
    .not("id", "is", null);

  if (error) {
    return { error: error.message };
  }

  await logAdminAction(supabase, {
    action: "product.bulk_set_redeemable",
    entityType: "product",
    metadata: { pointsToRedeem },
  });

  revalidatePath("/admin/products");
  return {
    success: `All products set redeemable at ${pointsToRedeem} points.`,
  };
}
