import Link from "next/link";
import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

export const adminControlClassName = cn(
  "h-10 w-full rounded-md border border-zinc-300 bg-white px-3 text-sm text-zinc-900 shadow-sm outline-none",
  "placeholder:text-zinc-400",
  "focus:border-zinc-500 focus:ring-2 focus:ring-zinc-200",
  "disabled:cursor-not-allowed disabled:bg-zinc-50 disabled:opacity-60",
);

export const adminTextareaClassName = cn(
  adminControlClassName,
  "min-h-24 h-auto py-2",
);

export const adminSelectClassName = adminControlClassName;

export function AdminPageHeader({
  title,
  description,
  breadcrumb,
  actions,
}: {
  title: string;
  description?: string;
  breadcrumb?: { href: string; label: string };
  actions?: ReactNode;
}) {
  return (
    <div className="sticky top-0 z-20 -mx-6 mb-2 border-b border-zinc-200 bg-zinc-100/95 px-6 py-4 backdrop-blur sm:-mx-8 sm:px-8">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0 space-y-1">
          {breadcrumb ? (
            <p className="text-sm text-zinc-500">
              <Link
                href={breadcrumb.href}
                className="font-medium text-zinc-600 underline-offset-2 hover:text-zinc-900 hover:underline"
              >
                {breadcrumb.label}
              </Link>
            </p>
          ) : null}
          <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">
            {title}
          </h1>
          {description ? (
            <p className="max-w-2xl text-sm text-zinc-500">{description}</p>
          ) : null}
        </div>
        {actions ? (
          <div className="flex shrink-0 flex-wrap items-center gap-2">
            {actions}
          </div>
        ) : null}
      </div>
    </div>
  );
}

export function AdminSection({
  title,
  description,
  children,
  className,
}: {
  title: string;
  description?: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section
      className={cn(
        "rounded-xl border border-zinc-200 bg-white shadow-sm",
        className,
      )}
    >
      <div className="border-b border-zinc-100 px-5 py-4">
        <h2 className="text-base font-semibold text-zinc-900">{title}</h2>
        {description ? (
          <p className="mt-0.5 text-sm text-zinc-500">{description}</p>
        ) : null}
      </div>
      <div className="px-5 py-5">{children}</div>
    </section>
  );
}

export function AdminField({
  label,
  htmlFor,
  hint,
  children,
  className,
}: {
  label: string;
  htmlFor?: string;
  hint?: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("flex flex-col gap-1.5", className)}>
      <label
        htmlFor={htmlFor}
        className="text-sm font-medium text-zinc-700"
      >
        {label}
      </label>
      {children}
      {hint ? <p className="text-xs text-zinc-500">{hint}</p> : null}
    </div>
  );
}

export function AdminCheckbox({
  name,
  defaultChecked,
  label,
  hint,
}: {
  name: string;
  defaultChecked?: boolean;
  label: string;
  hint?: string;
}) {
  return (
    <label className="flex cursor-pointer items-start gap-3 rounded-lg border border-zinc-200 bg-zinc-50/80 px-3 py-3">
      <input
        type="checkbox"
        name={name}
        defaultChecked={defaultChecked}
        className="mt-0.5 size-4 rounded border-zinc-300 text-zinc-900 focus:ring-zinc-400"
      />
      <span className="min-w-0">
        <span className="block text-sm font-medium text-zinc-800">{label}</span>
        {hint ? (
          <span className="mt-0.5 block text-xs text-zinc-500">{hint}</span>
        ) : null}
      </span>
    </label>
  );
}

export function AdminStatusPill({
  active,
  activeLabel = "Active",
  inactiveLabel = "Inactive",
}: {
  active: boolean;
  activeLabel?: string;
  inactiveLabel?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
        active
          ? "bg-emerald-50 text-emerald-700 ring-1 ring-emerald-200"
          : "bg-zinc-100 text-zinc-600 ring-1 ring-zinc-200",
      )}
    >
      {active ? activeLabel : inactiveLabel}
    </span>
  );
}

export function AdminTable({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "overflow-x-auto rounded-xl border border-zinc-200 bg-white shadow-sm",
        className,
      )}
    >
      <table className="w-full text-left text-sm">{children}</table>
    </div>
  );
}

export function AdminTableHead({ children }: { children: ReactNode }) {
  return (
    <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
      {children}
    </thead>
  );
}

export function AdminTh({
  children,
  className,
}: {
  children?: ReactNode;
  className?: string;
}) {
  return (
    <th className={cn("px-4 py-3 text-xs font-semibold uppercase tracking-wide", className)}>
      {children}
    </th>
  );
}

export function AdminTd({
  children,
  className,
}: {
  children?: ReactNode;
  className?: string;
}) {
  return <td className={cn("px-4 py-3 text-zinc-800", className)}>{children}</td>;
}
