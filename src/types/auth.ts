export type PerfilAcesso =
  | 'Administrador'
  | 'Financeiro'
  | 'Projetos'
  | 'Comercial'
  | 'Técnico'
  | 'Visualizador';

export interface PerfilUsuario {
  nome: string;
  perfil_acesso: PerfilAcesso;
  status: 'Ativo' | 'Inativo';
  avatar_url: string | null;
  departamento: string | null;
}

export interface PermissaoModulo {
  modulo: string;
  pode_ler: boolean;
  pode_escrever: boolean;
}
