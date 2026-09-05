import { redirect } from "next/navigation";
import { AccessPending } from "@/components/auth/access-pending";
import { SetupRequired } from "@/components/auth/setup-required";
import { AppShell } from "@/components/layout/app-shell";
import type { Profile } from "@/lib/auth/types";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function WorkspaceLayout({ children }: { children: React.ReactNode }) {
  if (!hasSupabaseEnv()) return <SetupRequired />;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data } = await supabase
    .from("profiles")
    .select("id,nome,email,avatar_url,cargo,role,ativo")
    .eq("id", user.id)
    .single();

  const profile = data as Profile | null;

  if (!profile?.ativo) {
    return <AccessPending email={profile?.email ?? user.email ?? "usuário atual"} />;
  }

  return <AppShell profile={profile}>{children}</AppShell>;
}
