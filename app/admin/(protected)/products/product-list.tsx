import Link from "next/link";

import {
  AdminStatusPill,
  AdminTable,
  AdminTableHead,
  AdminTd,
  AdminTh,
} from "@/components/admin/admin-ui";

export type AdminProductRow = {
  id: string;
  name: string;
  slug: string;
  categoryName: string;
  priceCents: number;
  isActive: boolean;
  isRedeemable: boolean;
  pointsToRedeem: number;
};

function formatMoney(cents: number): string {
  return (cents / 100).toLocaleString("en-GB", {
    style: "currency",
    currency: "GBP",
  });
}

export function ProductList({ products }: { products: AdminProductRow[] }) {
  if (products.length === 0) {
    return (
      <p className="rounded-xl border border-dashed border-zinc-300 bg-white px-4 py-8 text-center text-sm text-zinc-500">
        No products found.
      </p>
    );
  }

  return (
    <AdminTable>
      <AdminTableHead>
        <tr>
          <AdminTh>Name</AdminTh>
          <AdminTh>Category</AdminTh>
          <AdminTh>Price</AdminTh>
          <AdminTh>Redeemable</AdminTh>
          <AdminTh>Status</AdminTh>
          <AdminTh />
        </tr>
      </AdminTableHead>
      <tbody>
        {products.map((product) => (
          <tr
            key={product.id}
            className="border-b border-zinc-100 last:border-b-0 hover:bg-zinc-50/80"
          >
            <AdminTd>
              <div className="font-medium text-zinc-900">{product.name}</div>
              <div className="text-xs text-zinc-500">{product.slug}</div>
            </AdminTd>
            <AdminTd>{product.categoryName || "—"}</AdminTd>
            <AdminTd>{formatMoney(product.priceCents)}</AdminTd>
            <AdminTd>
              {product.isRedeemable ? (
                <span className="text-zinc-800">
                  Yes · {product.pointsToRedeem} pts
                </span>
              ) : (
                <span className="text-zinc-400">No</span>
              )}
            </AdminTd>
            <AdminTd>
              <AdminStatusPill active={product.isActive} />
            </AdminTd>
            <AdminTd className="text-right">
              <Link
                href={`/admin/products/${product.id}`}
                className="text-sm font-medium text-zinc-900 underline-offset-2 hover:underline"
              >
                Edit
              </Link>
            </AdminTd>
          </tr>
        ))}
      </tbody>
    </AdminTable>
  );
}
