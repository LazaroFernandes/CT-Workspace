import fs from "node:fs";
import { createClient } from "@supabase/supabase-js";

function readEnv(path) {
  return Object.fromEntries(
    fs
      .readFileSync(path, "utf8")
      .split(/\r?\n/)
      .filter((line) => line && !line.startsWith("#"))
      .map((line) => {
        const separator = line.indexOf("=");
        return [line.slice(0, separator), line.slice(separator + 1)];
      }),
  );
}

const publicEnv = readEnv(".env.local");
const testEnv = readEnv(".env.homologation.local");
const url = publicEnv.NEXT_PUBLIC_SUPABASE_URL;
const key = publicEnv.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const mode = process.argv[2] ?? "setup";
const results = [];

function record(name, pass, actual) {
  results.push({ name, pass, actual });
}

function client() {
  return createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

async function signIn(label, email, password) {
  const supabase = client();
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  record(`${label}: login`, !error && Boolean(data.user && data.session), error?.message ?? "session_created");
  if (error || !data.user || !data.session) throw new Error(`${label} login failed`);
  return { supabase, user: data.user };
}

async function expectOk(name, operation) {
  const { data, error } = await operation;
  const pass = !error;
  record(name, pass, error?.message ?? "allowed");
  if (!pass) throw new Error(`${name}: ${error.message}`);
  return data;
}

async function expectBlocked(name, operation) {
  const { data, error } = await operation;
  const empty = data == null || (Array.isArray(data) && data.length === 0);
  const pass = Boolean(error) || empty;
  record(name, pass, error?.code ?? (empty ? "zero_rows" : "unexpected_success"));
  return pass;
}

async function expectCount(name, operation, expected) {
  const { data, error } = await operation;
  const actual = Array.isArray(data) ? data.length : 0;
  const pass = !error && actual === expected;
  record(name, pass, error?.message ?? actual);
  return data ?? [];
}

async function authenticateAll() {
  const invalidClient = client();
  const invalid = await invalidClient.auth.signInWithPassword({
    email: testEnv.CTW_HOMOLOG_ADMIN_EMAIL,
    password: `${testEnv.CTW_HOMOLOG_ADMIN_PASSWORD}-invalid`,
  });
  record("AUTH: login inválido", Boolean(invalid.error), invalid.error ? "blocked" : "unexpected_success");

  const admin = await signIn(
    "ADMIN",
    testEnv.CTW_HOMOLOG_ADMIN_EMAIL,
    testEnv.CTW_HOMOLOG_ADMIN_PASSWORD,
  );
  const gestor = await signIn(
    "GESTOR",
    testEnv.CTW_HOMOLOG_GESTOR_EMAIL,
    testEnv.CTW_HOMOLOG_GESTOR_PASSWORD,
  );
  const membro = await signIn(
    "MEMBRO",
    testEnv.CTW_HOMOLOG_MEMBRO_EMAIL,
    testEnv.CTW_HOMOLOG_MEMBRO_PASSWORD,
  );

  const refresh = await admin.supabase.auth.refreshSession();
  record("AUTH: renovação de sessão", !refresh.error && Boolean(refresh.data.session), refresh.error?.message ?? "refreshed");

  return { admin, gestor, membro };
}

async function signOutAll(identities) {
  for (const [label, identity] of Object.entries(identities)) {
    const { error } = await identity.supabase.auth.signOut();
    const after = await identity.supabase.auth.getSession();
    record(
      `${label.toUpperCase()}: logout`,
      !error && after.data.session === null,
      error?.message ?? (after.data.session === null ? "session_removed" : "session_remained"),
    );
  }
}

async function setup() {
  const identities = await authenticateAll();
  const { admin, gestor } = identities;

  const companies = await expectOk(
    "ADMIN: ler empresas",
    admin.supabase.from("companies").select("id,nome,sigla").eq("sigla", "CT"),
  );
  const company = companies[0];
  const units = await expectOk(
    "ADMIN: ler unidade",
    admin.supabase.from("units").select("id,nome").eq("company_id", company.id).eq("sigla", "CT"),
  );
  const areas = await expectOk(
    "ADMIN: ler área",
    admin.supabase.from("areas").select("id,nome").eq("company_id", company.id).eq("sigla", "SIS"),
  );
  const unit = units[0];
  const area = areas[0];

  const adminProject = await expectOk(
    "ADMIN: criar projeto autorizado",
    admin.supabase
      .from("projects")
      .insert({
        codigo: "HOMOLOGACAO-RLS",
        titulo: "HOMOLOGAÇÃO RLS",
        descricao: "Projeto criado exclusivamente para homologação de RLS.",
        company_id: company.id,
        unit_id: unit.id,
        area_id: area.id,
        status: "EM_ANDAMENTO",
        prioridade: "ALTA",
        responsavel_principal_id: admin.user.id,
        proxima_acao: "Executar matriz de segurança",
        created_by: admin.user.id,
      })
      .select()
      .single(),
  );
  await expectOk(
    "ADMIN: editar projeto",
    admin.supabase
      .from("projects")
      .update({ prioridade: "CRITICA", proxima_acao: "Validar usuários reais" })
      .eq("id", adminProject.id)
      .select(),
  );
  const forbiddenProject = await expectOk(
    "ADMIN: criar projeto proibido",
    admin.supabase
      .from("projects")
      .insert({
        codigo: "HOMOLOGACAO-PRIVADO",
        titulo: "HOMOLOGAÇÃO PROJETO PROIBIDO",
        company_id: company.id,
        unit_id: unit.id,
        area_id: area.id,
        status: "EM_ANDAMENTO",
        prioridade: "MEDIA",
        responsavel_principal_id: admin.user.id,
        created_by: admin.user.id,
      })
      .select()
      .single(),
  );
  await expectOk(
    "ADMIN: vincular MEMBRO",
    admin.supabase
      .from("project_members")
      .insert({ project_id: adminProject.id, user_id: identities.membro.user.id, created_by: admin.user.id })
      .select(),
  );

  const stage = await expectOk(
    "ADMIN: criar etapa",
    admin.supabase
      .from("project_stages")
      .insert({
        project_id: adminProject.id,
        titulo: "Etapa de homologação",
        status: "EM_ANDAMENTO",
        ordem: 0,
        responsavel_id: identities.membro.user.id,
      })
      .select()
      .single(),
  );
  const checklist = await expectOk(
    "ADMIN: criar checklist",
    admin.supabase
      .from("checklist_items")
      .insert({
        stage_id: stage.id,
        titulo: "Validar acesso do membro",
        responsavel_id: identities.membro.user.id,
        ordem: 0,
      })
      .select()
      .single(),
  );
  await expectOk(
    "ADMIN: concluir checklist",
    admin.supabase.from("checklist_items").update({ is_completed: true }).eq("id", checklist.id).select(),
  );
  await expectOk(
    "ADMIN: reabrir checklist",
    admin.supabase.from("checklist_items").update({ is_completed: false }).eq("id", checklist.id).select(),
  );
  await expectOk(
    "ADMIN: registrar commit",
    admin.supabase
      .from("project_commits")
      .insert({
        project_id: adminProject.id,
        user_id: admin.user.id,
        titulo: "HOMOLOGAÇÃO: commit administrativo",
        tipo: "DECISAO",
        origem: "MANUAL",
      })
      .select(),
  );
  await expectOk(
    "ADMIN: operar Inbox",
    admin.supabase
      .from("inbox_items")
      .insert({
        titulo: "HOMOLOGAÇÃO: item administrativo",
        company_id: company.id,
        unit_id: unit.id,
        created_by: admin.user.id,
      })
      .select(),
  );

  await expectOk(
    "ADMIN: criar development_project autorizado",
    admin.supabase
      .from("development_projects")
      .insert({
        titulo: "HOMOLOGAÇÃO DEV AUTORIZADO",
        project_id: adminProject.id,
        status: "ATIVO",
        ambiente: "LOCAL",
        created_by: admin.user.id,
      })
      .select(),
  );
  await expectOk(
    "ADMIN: criar development_project proibido",
    admin.supabase
      .from("development_projects")
      .insert({
        titulo: "HOMOLOGAÇÃO DEV PROIBIDO",
        project_id: forbiddenProject.id,
        status: "ATIVO",
        ambiente: "LOCAL",
        created_by: admin.user.id,
      })
      .select(),
  );
  const independentDev = await expectOk(
    "ADMIN: criar development_project independente",
    admin.supabase
      .from("development_projects")
      .insert({
        titulo: "HOMOLOGAÇÃO DEV INDEPENDENTE",
        project_id: null,
        status: "ATIVO",
        ambiente: "LOCAL",
        created_by: admin.user.id,
      })
      .select()
      .single(),
  );
  await expectOk(
    "ADMIN: editar development_project",
    admin.supabase
      .from("development_projects")
      .update({
        repository_provider: "GITHUB",
        repository_owner: "homologacao",
        repository_name: "ct-workspace",
        repository_url: "https://github.com/homologacao/ct-workspace",
        default_branch: "main",
        ultimo_commit_sha: "abcdef1234567",
        ultimo_commit_titulo: "HOMOLOGAÇÃO: snapshot",
        ultimo_commit_autor: "Usuário de homologação",
        ultimo_commit_data: new Date().toISOString(),
        ultima_atividade: new Date().toISOString(),
      })
      .eq("id", independentDev.id)
      .select(),
  );
  const archivedDev = await expectOk(
    "ADMIN: criar development_project para arquivo",
    admin.supabase
      .from("development_projects")
      .insert({
        titulo: "HOMOLOGAÇÃO DEV ARQUIVAMENTO",
        status: "ATIVO",
        ambiente: "LOCAL",
        created_by: admin.user.id,
      })
      .select()
      .single(),
  );
  await expectOk(
    "ADMIN: arquivar development_project",
    admin.supabase
      .from("development_projects")
      .update({ status: "ARQUIVADO", archived_at: new Date().toISOString() })
      .eq("id", archivedDev.id)
      .select(),
  );

  const gestorProject = await expectOk(
    "GESTOR: criar projeto",
    gestor.supabase
      .from("projects")
      .insert({
        codigo: "HOMOLOGACAO-GESTOR",
        titulo: "HOMOLOGAÇÃO PROJETO GESTOR",
        company_id: company.id,
        unit_id: unit.id,
        area_id: area.id,
        status: "EM_PLANEJAMENTO",
        prioridade: "MEDIA",
        responsavel_principal_id: gestor.user.id,
        created_by: gestor.user.id,
      })
      .select()
      .single(),
  );
  await expectOk(
    "GESTOR: editar status, prioridade e próxima ação",
    gestor.supabase
      .from("projects")
      .update({ status: "EM_ANDAMENTO", prioridade: "ALTA", proxima_acao: "Executar homologação do gestor" })
      .eq("id", gestorProject.id)
      .select(),
  );
  const gestorStage = await expectOk(
    "GESTOR: criar etapa",
    gestor.supabase
      .from("project_stages")
      .insert({ project_id: gestorProject.id, titulo: "Etapa gestor", status: "EM_ANDAMENTO", ordem: 0 })
      .select()
      .single(),
  );
  const gestorChecklist = await expectOk(
    "GESTOR: criar checklist",
    gestor.supabase
      .from("checklist_items")
      .insert({ stage_id: gestorStage.id, titulo: "Checklist gestor", responsavel_id: gestor.user.id, ordem: 0 })
      .select()
      .single(),
  );
  await expectOk(
    "GESTOR: concluir checklist",
    gestor.supabase.from("checklist_items").update({ is_completed: true }).eq("id", gestorChecklist.id).select(),
  );
  await expectOk(
    "GESTOR: registrar commit",
    gestor.supabase
      .from("project_commits")
      .insert({
        project_id: gestorProject.id,
        user_id: gestor.user.id,
        titulo: "HOMOLOGAÇÃO: commit gestor",
        origem: "MANUAL",
      })
      .select(),
  );
  await expectOk(
    "GESTOR: operar Inbox",
    gestor.supabase
      .from("inbox_items")
      .insert({ titulo: "HOMOLOGAÇÃO: item gestor", created_by: gestor.user.id })
      .select(),
  );
  const gestorDev = await expectOk(
    "GESTOR: criar development_project",
    gestor.supabase
      .from("development_projects")
      .insert({
        titulo: "HOMOLOGAÇÃO DEV GESTOR",
        project_id: gestorProject.id,
        status: "ATIVO",
        ambiente: "DESENVOLVIMENTO",
        created_by: gestor.user.id,
      })
      .select()
      .single(),
  );
  await expectOk(
    "GESTOR: arquivar development_project",
    gestor.supabase
      .from("development_projects")
      .update({ status: "ARQUIVADO", archived_at: new Date().toISOString() })
      .eq("id", gestorDev.id)
      .select(),
  );

  await signOutAll(identities);
}

async function security() {
  const identities = await authenticateAll();
  const { admin, gestor, membro } = identities;

  const projects = await expectOk(
    "SEGURANÇA: localizar projetos",
    gestor.supabase
      .from("projects")
      .select("id,codigo,created_by,company_id,unit_id,area_id")
      .in("codigo", ["HOMOLOGACAO-RLS", "HOMOLOGACAO-PRIVADO", "HOMOLOGACAO-GESTOR"]),
  );
  const allowed = projects.find((item) => item.codigo === "HOMOLOGACAO-RLS");
  const forbidden = projects.find((item) => item.codigo === "HOMOLOGACAO-PRIVADO");
  const gestorProject = projects.find((item) => item.codigo === "HOMOLOGACAO-GESTOR");

  await expectCount(
    "MEMBRO: projeto autorizado",
    membro.supabase.from("projects").select("id").eq("id", allowed.id),
    1,
  );
  await expectCount(
    "MEMBRO: projeto proibido",
    membro.supabase.from("projects").select("id").eq("id", forbidden.id),
    0,
  );
  await expectCount(
    "MEMBRO: development_project autorizado",
    membro.supabase.from("development_projects").select("id").eq("titulo", "HOMOLOGAÇÃO DEV AUTORIZADO"),
    1,
  );
  await expectCount(
    "MEMBRO: development_project proibido",
    membro.supabase.from("development_projects").select("id").eq("titulo", "HOMOLOGAÇÃO DEV PROIBIDO"),
    0,
  );
  await expectCount(
    "MEMBRO: development_project independente",
    membro.supabase.from("development_projects").select("id").eq("titulo", "HOMOLOGAÇÃO DEV INDEPENDENTE"),
    0,
  );

  await expectBlocked(
    "GESTOR: autopromoção parcial",
    gestor.supabase.from("profiles").update({ role: "ADMIN" }).eq("id", gestor.user.id).select(),
  );
  await expectBlocked(
    "GESTOR: alterar próprio ativo",
    gestor.supabase.from("profiles").update({ ativo: false }).eq("id", gestor.user.id).select(),
  );
  await expectBlocked(
    "GESTOR: promover outro usuário",
    gestor.supabase.from("profiles").update({ role: "ADMIN" }).eq("id", membro.user.id).select(),
  );
  await expectBlocked(
    "GESTOR: inserir profile administrativo",
    gestor.supabase
      .from("profiles")
      .insert({
        id: "00000000-0000-0000-0000-000000000098",
        nome: "HOMOLOGAÇÃO ADMIN FALSO GESTOR",
        email: "ctw.homolog.false-admin-gestor@example.com",
        role: "ADMIN",
        ativo: true,
      })
      .select(),
  );
  await expectBlocked(
    "MEMBRO: autopromoção parcial",
    membro.supabase.from("profiles").update({ role: "ADMIN" }).eq("id", membro.user.id).select(),
  );
  await expectBlocked(
    "MEMBRO: alterar próprio ativo",
    membro.supabase.from("profiles").update({ ativo: false }).eq("id", membro.user.id).select(),
  );
  await expectBlocked(
    "MEMBRO: alterar papel de outro usuário",
    membro.supabase.from("profiles").update({ role: "MEMBRO" }).eq("id", admin.user.id).select(),
  );
  await expectBlocked(
    "MEMBRO: inserir profile administrativo",
    membro.supabase
      .from("profiles")
      .insert({
        id: "00000000-0000-0000-0000-000000000099",
        nome: "HOMOLOGAÇÃO ADMIN FALSO",
        email: "ctw.homolog.false-admin@example.com",
        role: "ADMIN",
        ativo: true,
      })
      .select(),
  );
  await expectBlocked(
    "MEMBRO: modificar projeto",
    membro.supabase.from("projects").update({ prioridade: "CRITICA" }).eq("id", allowed.id).select(),
  );
  await expectBlocked(
    "MEMBRO: modificar created_by",
    membro.supabase.from("projects").update({ created_by: membro.user.id }).eq("id", allowed.id).select(),
  );
  await expectBlocked(
    "MEMBRO: inserir empresa",
    membro.supabase.from("companies").insert({ nome: "HOMOLOGAÇÃO EMPRESA", sigla: "HTE" }).select(),
  );
  await expectBlocked(
    "MEMBRO: modificar empresa",
    membro.supabase.from("companies").update({ nome: "HOMOLOGAÇÃO ALTERADA" }).eq("sigla", "CT").select(),
  );
  await expectBlocked(
    "GESTOR: modificar empresa",
    gestor.supabase.from("companies").update({ nome: "HOMOLOGAÇÃO ALTERADA" }).eq("sigla", "CT").select(),
  );
  await expectBlocked(
    "GESTOR: inserir projeto com created_by de terceiro",
    gestor.supabase
      .from("projects")
      .insert({
        codigo: "HOMOLOGACAO-FALSO-AUTOR",
        titulo: "HOMOLOGAÇÃO FALSO AUTOR",
        company_id: gestorProject.company_id,
        unit_id: gestorProject.unit_id,
        area_id: gestorProject.area_id,
        created_by: membro.user.id,
      })
      .select(),
  );

  await expectBlocked(
    "GESTOR: modificar created_by existente",
    gestor.supabase
      .from("projects")
      .update({ created_by: membro.user.id })
      .eq("id", gestorProject.id)
      .select(),
  );

  const checklist = await expectOk(
    "SEGURANÇA: localizar checklist concluído",
    gestor.supabase
      .from("checklist_items")
      .select("id,completed_by")
      .eq("titulo", "Checklist gestor")
      .single(),
  );
  await expectBlocked(
    "GESTOR: modificar completed_by",
    gestor.supabase
      .from("checklist_items")
      .update({ completed_by: membro.user.id })
      .eq("id", checklist.id)
      .select(),
  );

  const assignedChecklist = await expectOk(
    "SEGURANÇA: localizar checklist do MEMBRO",
    membro.supabase
      .from("checklist_items")
      .select("id")
      .eq("titulo", "Validar acesso do membro")
      .single(),
  );
  await expectBlocked(
    "MEMBRO: modificar completed_by",
    membro.supabase
      .from("checklist_items")
      .update({ completed_by: admin.user.id })
      .eq("id", assignedChecklist.id)
      .select(),
  );

  for (const functionName of [
    "can_access_project",
    "can_manage_projects",
    "can_update_checklist",
    "current_user_role",
    "is_active_user",
    "is_admin",
  ]) {
    const args =
      functionName === "can_access_project"
        ? { target_project_id: forbidden.id }
        : functionName === "can_update_checklist"
          ? { target_item_id: checklist.id }
          : {};
    await expectBlocked(
      `RPC público bloqueado: ${functionName}`,
      membro.supabase.rpc(functionName, args),
    );
  }
  await expectBlocked(
    "GESTOR: RPC público bloqueado",
    gestor.supabase.rpc("is_admin"),
  );

  const memberChecklist = await expectOk(
    "MEMBRO: localizar checklist atribuído",
    membro.supabase
      .from("checklist_items")
      .select("id")
      .eq("titulo", "Validar acesso do membro")
      .single(),
  );
  const completed = await expectOk(
    "MEMBRO: concluir checklist atribuído",
    membro.supabase
      .from("checklist_items")
      .update({ is_completed: true })
      .eq("id", memberChecklist.id)
      .select("id,is_completed,completed_by")
      .single(),
  );
  record(
    "MEMBRO: completed_by automático",
    completed.completed_by === membro.user.id,
    completed.completed_by === membro.user.id ? "current_user" : "unexpected_user",
  );
  await expectOk(
    "MEMBRO: registrar commit autorizado",
    membro.supabase
      .from("project_commits")
      .insert({
        project_id: allowed.id,
        user_id: membro.user.id,
        titulo: "HOMOLOGAÇÃO: commit membro",
        origem: "MANUAL",
      })
      .select(),
  );

  await signOutAll(identities);
}

async function inactive() {
  const membro = await signIn(
    "MEMBRO INATIVO",
    testEnv.CTW_HOMOLOG_MEMBRO_EMAIL,
    testEnv.CTW_HOMOLOG_MEMBRO_PASSWORD,
  );

  await expectCount(
    "MEMBRO INATIVO: empresas invisíveis",
    membro.supabase.from("companies").select("id"),
    0,
  );
  await expectCount(
    "MEMBRO INATIVO: projetos invisíveis",
    membro.supabase.from("projects").select("id"),
    0,
  );
  await expectBlocked(
    "MEMBRO INATIVO: operação bloqueada",
    membro.supabase
      .from("project_commits")
      .insert({
        project_id: "00000000-0000-0000-0000-000000000001",
        user_id: membro.user.id,
        titulo: "HOMOLOGAÇÃO: tentativa inativa",
        origem: "MANUAL",
      })
      .select(),
  );

  await signOutAll({ membro });
}

async function adminConfiguration() {
  const admin = await signIn(
    "ADMIN CONFIG",
    testEnv.CTW_HOMOLOG_ADMIN_EMAIL,
    testEnv.CTW_HOMOLOG_ADMIN_PASSWORD,
  );

  const company = await expectOk(
    "ADMIN: criar empresa de homologação",
    admin.supabase
      .from("companies")
      .insert({ nome: "HOMOLOGAÇÃO ADMIN", sigla: "HOM" })
      .select()
      .single(),
  );
  await expectOk(
    "ADMIN: editar empresa de homologação",
    admin.supabase.from("companies").update({ nome: "HOMOLOGAÇÃO ADMIN EDITADA" }).eq("id", company.id).select(),
  );
  const unit = await expectOk(
    "ADMIN: criar unidade de homologação",
    admin.supabase
      .from("units")
      .insert({ company_id: company.id, nome: "HOMOLOGAÇÃO UNIDADE", sigla: "HOMU" })
      .select()
      .single(),
  );
  await expectOk(
    "ADMIN: editar unidade de homologação",
    admin.supabase.from("units").update({ nome: "HOMOLOGAÇÃO UNIDADE EDITADA" }).eq("id", unit.id).select(),
  );
  const area = await expectOk(
    "ADMIN: criar área de homologação",
    admin.supabase
      .from("areas")
      .insert({ company_id: company.id, unit_id: unit.id, nome: "HOMOLOGAÇÃO ÁREA", sigla: "HOMA" })
      .select()
      .single(),
  );
  await expectOk(
    "ADMIN: editar área de homologação",
    admin.supabase.from("areas").update({ nome: "HOMOLOGAÇÃO ÁREA EDITADA" }).eq("id", area.id).select(),
  );

  const gestorProfile = await expectOk(
    "ADMIN: localizar perfil GESTOR",
    admin.supabase.from("profiles").select("id").eq("email", testEnv.CTW_HOMOLOG_GESTOR_EMAIL).single(),
  );
  await expectOk(
    "ADMIN: alterar papel administrativo",
    admin.supabase.from("profiles").update({ role: "MEMBRO" }).eq("id", gestorProfile.id).select(),
  );
  await expectOk(
    "ADMIN: restaurar papel GESTOR",
    admin.supabase.from("profiles").update({ role: "GESTOR" }).eq("id", gestorProfile.id).select(),
  );

  await signOutAll({ admin });
}

try {
  if (mode === "setup") await setup();
  else if (mode === "security") await security();
  else if (mode === "inactive") await inactive();
  else if (mode === "admin-config") await adminConfiguration();
  else throw new Error(`Unknown mode: ${mode}`);
} catch (error) {
  record("HARNESS", false, error instanceof Error ? error.message : "unknown_error");
}

const failed = results.filter((result) => !result.pass);
console.log(JSON.stringify({ mode, total: results.length, passed: results.length - failed.length, failed }, null, 2));
process.exitCode = failed.length === 0 ? 0 : 1;
