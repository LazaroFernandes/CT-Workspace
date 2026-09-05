import { Database } from "lucide-react";

export function SetupRequired() {
  return (
    <main className="grid min-h-screen place-items-center px-6">
      <section className="w-full max-w-lg rounded-2xl border border-[var(--border)] bg-white p-8 shadow-sm">
        <div className="grid size-11 place-items-center rounded-xl bg-[var(--brand-soft)] text-[var(--brand)]">
          <Database className="size-5" />
        </div>
        <p className="mt-6 text-sm font-semibold text-[var(--brand)]">Configuração local</p>
        <h1 className="mt-2 text-2xl font-semibold tracking-tight">Conecte o projeto ao Supabase</h1>
        <p className="mt-3 text-sm leading-6 text-[var(--muted)]">
          Copie <code className="rounded bg-[var(--surface-subtle)] px-1.5 py-0.5">.env.example</code> para{" "}
          <code className="rounded bg-[var(--surface-subtle)] px-1.5 py-0.5">.env.local</code> e informe a URL e a chave pública do projeto.
        </p>
      </section>
    </main>
  );
}
