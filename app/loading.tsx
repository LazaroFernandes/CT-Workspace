export default function Loading() {
  return (
    <main className="grid min-h-screen place-items-center bg-[var(--background)]">
      <div className="flex items-center gap-3 text-sm text-[var(--muted)]">
        <span className="size-2 animate-pulse rounded-full bg-[var(--brand)]" />
        Carregando workspace...
      </div>
    </main>
  );
}
