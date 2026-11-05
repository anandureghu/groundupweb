import type { Metadata } from "next";

import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

import { AdminLoginForm } from "./login-form";

export const metadata: Metadata = {
  title: "Admin login",
};

export default function AdminLoginPage() {
  return (
    <div className="flex min-h-screen w-full items-center justify-center bg-background px-6 py-12">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Admin login</CardTitle>
          <CardDescription>
            Sign in with your staff account to access the admin portal.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <AdminLoginForm />
        </CardContent>
      </Card>
    </div>
  );
}
