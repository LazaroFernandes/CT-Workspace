
create or replace function public.protect_created_by_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null
     and new.created_by is distinct from old.created_by then
    raise exception 'O campo created_by é imutável.';
  end if;

  return new;
end;
$$;

create trigger projects_protect_created_by
before update on public.projects
for each row execute function public.protect_created_by_immutable();

create trigger project_members_protect_created_by
before update on public.project_members
for each row execute function public.protect_created_by_immutable();

create trigger conversations_protect_created_by
before update on public.related_conversations
for each row execute function public.protect_created_by_immutable();

create trigger links_protect_created_by
before update on public.related_links
for each row execute function public.protect_created_by_immutable();

create trigger inbox_protect_created_by
before update on public.inbox_items
for each row execute function public.protect_created_by_immutable();

create trigger development_projects_protect_created_by
before update on public.development_projects
for each row execute function public.protect_created_by_immutable();

create or replace function public.sync_checklist_completion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.is_completed then
      if auth.uid() is not null
         and (new.completed_at is not null or new.completed_by is not null) then
        raise exception 'completed_at e completed_by são preenchidos automaticamente.';
      end if;

      new.completed_at = coalesce(new.completed_at, now());
      new.completed_by = coalesce(auth.uid(), new.completed_by);
    else
      new.completed_at = null;
      new.completed_by = null;
    end if;

    return new;
  end if;

  if new.is_completed is distinct from old.is_completed then
    if new.is_completed then
      if auth.uid() is not null
         and (new.completed_at is not null or new.completed_by is not null) then
        raise exception 'completed_at e completed_by são preenchidos automaticamente.';
      end if;

      new.completed_at = coalesce(new.completed_at, now());
      new.completed_by = coalesce(auth.uid(), new.completed_by, old.completed_by);
    else
      new.completed_at = null;
      new.completed_by = null;
    end if;
  elsif auth.uid() is not null
        and (
          new.completed_at is distinct from old.completed_at
          or new.completed_by is distinct from old.completed_by
        ) then
    raise exception 'completed_at e completed_by são imutáveis fora da conclusão ou reabertura.';
  elsif not new.is_completed then
    new.completed_at = null;
    new.completed_by = null;
  end if;

  return new;
end;
$$;

revoke all on function public.protect_created_by_immutable() from public, anon, authenticated;

drop trigger if exists checklist_sync_completion on public.checklist_items;
create trigger checklist_sync_completion
before insert or update on public.checklist_items
for each row execute function public.sync_checklist_completion();
