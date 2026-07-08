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
  departamento: string | null;
}

export interface PermissaoModulo {
  modulo: string;
  pode_ler: boolean;
  pode_escrever: boolean;
}

/**
 * Capacidade nomeada do RBAC (ex.: 'clientes.criar', 'tarefas.editar_propria').
 * Lista de capacidades do usuário autenticado, usada apenas para UX no frontend;
 * a autorização real é sempre validada pelas RPCs no backend.
 */
export type Capacidades = string[];
