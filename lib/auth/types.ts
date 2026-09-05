export type AppRole = "ADMIN" | "GESTOR" | "MEMBRO";

export type Profile = {
  id: string;
  nome: string;
  email: string;
  avatar_url: string | null;
  cargo: string | null;
  role: AppRole;
  ativo: boolean;
};
