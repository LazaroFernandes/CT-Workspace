import Link from "next/link";

export default function NotFound() {
  return (
    <main className="grid min-h-screen place-items-center px-6">
      <div className="max-w-md text-center">
        <p className="text-sm font-semibold text-[var(--brand)]">Página não encontrada</p>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight">Este caminho não existe.</h1>
        <p className="mt-3 text-sm leading-6 text-[var(--muted)]">
          Volte ao painel para continuar acompanhando os projetos.
        </p>
        <Link
          href="/dashboard"
          className="mt-7 inline-flex rounded-lg bg-[var(--brand)] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[var(--brand-strong)]"
        >
          Ir para o dashboard
        </Link>
      </div>
    </main>
  );
}
