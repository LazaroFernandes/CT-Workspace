"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Building2,
  ChartNoAxesCombined,
  ChevronRight,
  Code2,
  FolderKanban,
  Inbox,
  Layers3,
  LogOut,
  Menu,
  Settings,
  Users,
  X,
} from "lucide-react";
import { signOut } from "@/app/(workspace)/actions";
import type { Profile } from "@/lib/auth/types";

type AppShellProps = {
  profile: Profile;
  children: React.ReactNode;
};

const workspaceItems = [
  { label: "Dashboard", href: "/dashboard", icon: ChartNoAxesCombined, ready: true },
  { label: "Inbox", href: "/inbox", icon: Inbox, ready: false },
  { label: "Projetos", href: "/projetos", icon: FolderKanban, ready: false },
  { label: "Desenvolvimento", href: "/desenvolvimento", icon: Code2, ready: false },
];

const adminItems = [
  { label: "Empresas", href: "/empresas", icon: Building2 },
  { label: "Unidades", href: "/unidades", icon: Layers3 },
  { label: "Áreas", href: "/areas", icon: ChevronRight },
  { label: "Equipe", href: "/equipe", icon: Users },
  { label: "Configurações", href: "/configuracoes", icon: Settings },
];

const roleLabels = {
  ADMIN: "Administrador",
  GESTOR: "Gestor",
  MEMBRO: "Membro",
};

function SidebarContent({ profile, close }: { profile: Profile; close?: () => void }) {
  const pathname = usePathname();

  return (
    <div className="flex h-full flex-col">
      <div className="flex h-18 items-center gap-3 border-b border-white/10 px-5">
        <div className="grid size-9 place-items-center rounded-xl bg-white text-xs font-extrabold text-[#183c2d]">
          CT
        </div>
        <div>
          <p className="text-sm font-semibold tracking-tight text-white">CT Workspace</p>
          <p className="mt-0.5 text-[11px] text-emerald-100/55">Gestão de projetos</p>
        </div>
      </div>

      <nav aria-label="Navegação principal" className="flex-1 overflow-y-auto px-3 py-5">
        <p className="px-3 text-[10px] font-bold uppercase tracking-[0.16em] text-emerald-100/40">
          Workspace
        </p>
        <div className="mt-2 space-y-1">
          {workspaceItems.map((item) => {
            const active = pathname === item.href;
            const Icon = item.icon;

            if (!item.ready) {
              return (
                <div
                  key={item.href}
                  className="flex h-10 items-center gap-3 rounded-lg px-3 text-sm text-emerald-50/45"
                  aria-disabled="true"
                >
                  <Icon className="size-[18px]" />
                  <span className="flex-1">{item.label}</span>
                  <span className="text-[9px] font-semibold uppercase tracking-wider">Em breve</span>
                </div>
              );
            }

            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={close}
                className={`flex h-10 items-center gap-3 rounded-lg px-3 text-sm font-medium transition ${
                  active
                    ? "bg-white/12 text-white"
                    : "text-emerald-50/70 hover:bg-white/7 hover:text-white"
                }`}
              >
                <Icon className="size-[18px]" />
                {item.label}
              </Link>
            );
          })}
        </div>

        {profile.role === "ADMIN" ? (
          <div className="mt-7">
            <p className="px-3 text-[10px] font-bold uppercase tracking-[0.16em] text-emerald-100/40">
              Administração
            </p>
            <div className="mt-2 space-y-1">
              {adminItems.map((item) => {
                const Icon = item.icon;
                return (
                  <div
                    key={item.href}
                    className="flex h-10 items-center gap-3 rounded-lg px-3 text-sm text-emerald-50/45"
                    aria-disabled="true"
                  >
                    <Icon className="size-[18px]" />
                    <span className="flex-1">{item.label}</span>
                    <span className="text-[9px] font-semibold uppercase tracking-wider">Em breve</span>
                  </div>
                );
              })}
            </div>
          </div>
        ) : null}
      </nav>

      <div className="border-t border-white/10 p-3">
        <div className="flex items-center gap-3 rounded-xl bg-black/10 p-3">
          <div className="grid size-9 shrink-0 place-items-center rounded-full bg-emerald-100 text-xs font-bold text-[#183c2d]">
            {profile.nome.slice(0, 2).toUpperCase()}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium text-white">{profile.nome}</p>
            <p className="truncate text-[11px] text-emerald-100/55">{roleLabels[profile.role]}</p>
          </div>
          <form action={signOut}>
            <button
              type="submit"
              aria-label="Sair"
              title="Sair"
              className="grid size-8 place-items-center rounded-lg text-emerald-50/55 transition hover:bg-white/10 hover:text-white"
            >
              <LogOut className="size-4" />
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

export function AppShell({ profile, children }: AppShellProps) {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <div className="min-h-screen bg-[var(--background)]">
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 bg-[#183c2d] lg:block">
        <SidebarContent profile={profile} />
      </aside>

      <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-[var(--border)] bg-white/90 px-4 backdrop-blur lg:hidden">
        <button
          type="button"
          onClick={() => setMobileOpen(true)}
          className="grid size-10 place-items-center rounded-lg border border-[var(--border)]"
          aria-label="Abrir navegação"
        >
          <Menu className="size-5" />
        </button>
        <span className="text-sm font-semibold">CT Workspace</span>
        <div className="size-10" />
      </header>

      {mobileOpen ? (
        <div className="fixed inset-0 z-50 lg:hidden">
          <button
            type="button"
            className="absolute inset-0 bg-black/45"
            aria-label="Fechar navegação"
            onClick={() => setMobileOpen(false)}
          />
          <aside className="absolute inset-y-0 left-0 w-[min(82vw,20rem)] bg-[#183c2d] shadow-2xl">
            <button
              type="button"
              onClick={() => setMobileOpen(false)}
              aria-label="Fechar navegação"
              className="absolute right-3 top-4 z-10 grid size-9 place-items-center rounded-lg text-white/70 hover:bg-white/10 hover:text-white"
            >
              <X className="size-5" />
            </button>
            <SidebarContent profile={profile} close={() => setMobileOpen(false)} />
          </aside>
        </div>
      ) : null}

      <div className="lg:pl-64">
        <main className="mx-auto max-w-[1500px] px-4 py-7 sm:px-7 lg:px-10 lg:py-10">{children}</main>
      </div>
    </div>
  );
}
