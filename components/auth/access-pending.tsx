import { ShieldAlert } from "lucide-react";
import { signOut } from "@/app/(workspace)/actions";

export function AccessPending({ email }: { email: string }) {
  return (
    <main className="grid min-h-screen place-items-center px-6">
      <section className="w-full max-w-md rounded-2xl border border-[var(--border)] bg-white p-8 shadow-sm">
        <div className="grid size-11 place-items-center rounded-xl bg-amber-50 text-amber-700">
          <ShieldAlert className="size-5" />
        </div>
        <h1 className="mt-6 text-2xl font-semibold tracking-tight">Acesso aguardando liberação</h1>
        <p className="mt-3 text-sm leading-6 text-[var(--muted)]">
          O perfil <strong className="font-medium text-[var(--foreground)]">{email}</strong> foi autenticado,
          mas ainda precisa ser ativado por um administrador.
        </p>
        <form action={signOut} className="mt-7">
          <button className="rounded-lg border border-[var(--border)] px-4 py-2.5 text-sm font-semibold hover:bg-[var(--surface-subtle)]">
            Sair
          </button>
        </form>
      </section>
    </main>
  );
}
