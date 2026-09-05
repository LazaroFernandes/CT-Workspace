insert into public.companies (nome, sigla)
values
  ('CT Ítalo Vieira', 'CT'),
  ('Netmitt', 'NET')
on conflict do nothing;

insert into public.units (company_id, nome, sigla)
select c.id, seed.nome, seed.sigla
from public.companies c
join (
  values
    ('CT', 'CT Ítalo Vieira', 'CT'),
    ('NET', 'Campo Bom', 'CB'),
    ('NET', 'Canudos', 'CAN'),
    ('NET', 'Rondônia', 'RO')
) as seed(company_sigla, nome, sigla) on seed.company_sigla = c.sigla
where c.archived_at is null
on conflict do nothing;

insert into public.areas (company_id, nome, sigla)
select c.id, seed.nome, seed.sigla
from public.companies c
cross join (
  values
    ('Operação', 'OPS'),
    ('Comercial', 'COM'),
    ('Professores', 'PROF'),
    ('Jornada do Aluno', 'JORN'),
    ('Gestão', 'GES'),
    ('Sistemas', 'SIS'),
    ('Marketing', 'MKT'),
    ('Financeiro', 'FIN'),
    ('RH', 'RH'),
    ('Treinamento', 'TRE'),
    ('Infraestrutura', 'INFRA'),
    ('Estratégia', 'EST')
) as seed(nome, sigla)
where c.archived_at is null
  and not exists (
    select 1
    from public.areas a
    where a.company_id = c.id
      and a.unit_id is null
      and lower(a.nome) = lower(seed.nome)
      and a.archived_at is null
  );
