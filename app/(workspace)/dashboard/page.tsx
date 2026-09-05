import type { Metadata } from "next";
import {
  AlertTriangle,
  ArrowUpRight,
  Ban,
  CheckCircle2,
  CircleDot,
  Clock3,
  FolderKanban,
} from "lucide-react";

export const metadata: Metadata = { title: "Dashboard" };

const indicators = [
  { label: "Projetos ativos", icon: FolderKanban, tone: "text-slate-700 bg-slate-100" },
  { label: "Em andamento", icon: CircleDot, tone: "text-blue-700 bg-blue-50" },
  { label: "Aguardando", icon: Clock3, tone: "text-amber-700 bg-amber-50" },
  { label: "Bloqueados", icon: Ban, tone: "text-red-700 bg-red-50" },
  { label: "Concluídos no mês", icon: CheckCircle2, tone: "text-emerald-700 bg-emerald-50" },
  { label: "Prioridade crítica", icon: AlertTriangle, tone: "text-orange-700 bg-orange-50" },
];

export default function DashboardPage() {
  return (
    <div>
      <header className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-sm font-semibold text-[var(--brand)]">Visão geral</p>
          <h1 className="mt-1 text-3xl font-semibold tracking-[-0.035em]">Dashboard</h1>
          <p className="mt-2 text-sm text-[var(--muted)]">
            A fundação está pronta para receber os dados das próximas fases.
          </p>
        </div>
        <span className="w-fit rounded-full border border-[var(--border)] bg-white px-3 py-1.5 text-xs font-medium text-[var(--muted)]">
          Fase 0 · Fundação
        </span>
      </header>

      <section aria-label="Indicadores" className="mt-8 grid gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
        {indicators.map((indicator) => {
          const Icon = indicator.icon;
          return (
            <article key={indicator.label} className="rounded-xl border border-[var(--border)] bg-white p-4 shadow-[0_1px_2px_rgba(18,45,31,0.03)]">
              <div className={`grid size-8 place-items-center rounded-lg ${indicator.tone}`}>
                <Icon className="size-4" />
              </div>
              <p className="mt-5 text-2xl font-semibold tracking-tight">—</p>
              <p className="mt-1 text-xs leading-5 text-[var(--muted)]">{indicator.label}</p>
            </article>
          );
        })}
      </section>

      <section className="mt-6 grid gap-6 xl:grid-cols-[1.45fr_0.85fr]">
        <article className="min-h-72 rounded-xl border border-[var(--border)] bg-white">
          <div className="flex items-center justify-between border-b border-[var(--border)] px-5 py-4">
            <div>
              <h2 className="font-semibold tracking-tight">Projetos que precisam de atenção</h2>
              <p className="mt-1 text-xs text-[var(--muted)]">Bloqueios, prazos e falta de atualização.</p>
            </div>
            <ArrowUpRight className="size-4 text-[var(--muted)]" />
          </div>
          <div className="grid min-h-52 place-items-center px-6 text-center">
            <div className="max-w-xs">
              <div className="mx-auto grid size-10 place-items-center rounded-xl bg-[var(--surface-subtle)] text-[var(--muted)]">
                <FolderKanban className="size-5" />
              </div>
              <p className="mt-4 text-sm font-medium">Nenhum projeto cadastrado</p>
              <p className="mt-1.5 text-xs leading-5 text-[var(--muted)]">A gestão de projetos será implementada na Fase 1.</p>
            </div>
          </div>
        </article>

        <article className="min-h-72 rounded-xl border border-[var(--border)] bg-white">
          <div className="border-b border-[var(--border)] px-5 py-4">
            <h2 className="font-semibold tracking-tight">Últimos commits</h2>
            <p className="mt-1 text-xs text-[var(--muted)]">Atualizações relevantes do workspace.</p>
          </div>
          <div className="grid min-h-52 place-items-center px-6 text-center">
            <div className="max-w-xs">
              <div className="mx-auto grid size-10 place-items-center rounded-xl bg-[var(--surface-subtle)] text-[var(--muted)]">
                <Clock3 className="size-5" />
              </div>
              <p className="mt-4 text-sm font-medium">A timeline está vazia</p>
              <p className="mt-1.5 text-xs leading-5 text-[var(--muted)]">Commits serão exibidos aqui a partir da Fase 3.</p>
            </div>
          </div>
        </article>
      </section>
    </div>
  );
}
