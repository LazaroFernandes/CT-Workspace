import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { LoginForm } from "@/components/auth/login-form";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Entrar" };
export const dynamic = "force-dynamic";

export default async function LoginPage() {
  if (hasSupabaseEnv()) {
    const supabase = await createClient();
    const { data } = await supabase.auth.getUser();
    if (data.user) redirect("/dashboard");
  }

  return (
    <div className="grid min-h-screen lg:grid-cols-[1.1fr_0.9fr]">
      <section className="hidden overflow-hidden bg-[#183c2d] p-12 text-white lg:flex lg:flex-col lg:justify-between">
        <div className="flex items-center gap-3">
          <div className="grid size-10 place-items-center rounded-xl bg-white/10 text-sm font-bold ring-1 ring-white/15">
            CT
          </div>
          <span className="font-semibold tracking-tight">CT Workspace</span>
        </div>

        <div className="max-w-xl">
          <p className="mb-5 text-xs font-semibold uppercase tracking-[0.18em] text-emerald-200">
            Clareza operacional
          </p>
          <h1 className="text-5xl font-semibold leading-[1.08] tracking-[-0.04em]">
            Tudo o que está sendo construído, em um só lugar.
          </h1>
          <p className="mt-6 max-w-lg text-base leading-7 text-emerald-50/75">
            Projetos, próximas ações e decisões importantes com histórico claro para a equipe.
          </p>
        </div>

        <p className="text-xs text-emerald-100/55">CT Ítalo Vieira · Netmitt</p>
      </section>

      <section className="flex items-center justify-center px-6 py-12 sm:px-10">
        <div className="w-full max-w-sm">
          <div className="mb-10 flex items-center gap-3 lg:hidden">
            <div className="grid size-10 place-items-center rounded-xl bg-[var(--brand)] text-sm font-bold text-white">
              CT
            </div>
            <span className="font-semibold tracking-tight">CT Workspace</span>
          </div>

          <p className="text-sm font-semibold text-[var(--brand)]">Acesso interno</p>
          <h2 className="mt-2 text-3xl font-semibold tracking-[-0.03em]">Bem-vindo de volta</h2>
          <p className="mt-3 text-sm leading-6 text-[var(--muted)]">
            Entre com as credenciais cadastradas pela administração.
          </p>
          <LoginForm />
        </div>
      </section>
    </div>
  );
}
