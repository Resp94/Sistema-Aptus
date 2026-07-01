import { supabase } from './supabase'
import type {
  ConfiguracaoEmpresa,
  UsuarioConfigItem,
  PreferenciaNotificacaoItem,
  AuditoriaEventoItem
} from '../types/configuracoes'

export const configuracoesService = {
  // --- CONFIGURAÇÕES DA EMPRESA (Restrito a Admin) ---
  async obterConfiguracoesEmpresa(): Promise<ConfiguracaoEmpresa> {
    const { data, error } = await supabase.rpc('obter_configuracoes_empresa')

    if (error) {
      console.error('Erro ao obter configurações da empresa:', error)
      throw new Error(error.message || 'Erro ao carregar configurações globais.')
    }

    // Retorna a linha única
    return (Array.isArray(data) ? data[0] : data) as ConfiguracaoEmpresa
  },

  async atualizarConfiguracoesEmpresa(payload: Partial<ConfiguracaoEmpresa>): Promise<boolean> {
    const { data, error } = await supabase.rpc('atualizar_configuracoes_empresa', {
      payload
    })

    if (error) {
      console.error('Erro ao atualizar configurações da empresa:', error)
      throw new Error(error.message || 'Erro ao salvar alterações da empresa.')
    }

    return !!data
  },

  // --- CONTAS E USUÁRIOS (Restrito a Admin) ---
  async listarUsuariosConfiguracoes(): Promise<UsuarioConfigItem[]> {
    const { data, error } = await supabase.rpc('listar_usuarios_configuracoes')

    if (error) {
      console.error('Erro ao listar usuários do sistema:', error)
      throw new Error(error.message || 'Erro ao carregar lista de usuários.')
    }

    return (data || []) as UsuarioConfigItem[]
  },

  async atualizarUsuarioPerfil(
    usuarioId: string,
    payload: {
      perfil_acesso?: string
      status?: 'Ativo' | 'Inativo'
      departamento?: string | null
    }
  ): Promise<boolean> {
    const { data, error } = await supabase.rpc('atualizar_usuario_perfil', {
      p_usuario_id: usuarioId,
      payload
    })

    if (error) {
      console.error('Erro ao gerenciar conta do usuário:', error)
      throw new Error(error.message || 'Erro ao atualizar dados do usuário.')
    }

    return !!data
  },

  // --- MINHA CONTA (Todos os usuários logados) ---
  async obterMinhasConfiguracoes(): Promise<{ perfil: any; usuario: any }> {
    const { data, error } = await supabase.rpc('obter_minhas_configuracoes')

    if (error) {
      console.error('Erro ao obter minhas configurações:', error)
      throw new Error(error.message || 'Erro ao carregar seus dados cadastrais.')
    }

    return data as { perfil: any; usuario: any }
  },

  async atualizarMinhasConfiguracoes(payload: {
    nome?: string
    avatar_url?: string | null
    departamento?: string | null
  }): Promise<boolean> {
    const { data, error } = await supabase.rpc('atualizar_minhas_configuracoes', {
      payload
    })

    if (error) {
      console.error('Erro ao atualizar minhas configurações:', error)
      throw new Error(error.message || 'Erro ao salvar seus dados cadastrais.')
    }

    return !!data
  },

  // --- PREFERÊNCIAS DE NOTIFICAÇÕES (Todos os usuários logados) ---
  async listarPreferenciasNotificacoes(): Promise<PreferenciaNotificacaoItem[]> {
    const { data, error } = await supabase.rpc('listar_preferencias_notificacoes')

    if (error) {
      console.error('Erro ao listar preferências de notificações:', error)
      throw new Error(error.message || 'Erro ao obter preferências de notificação.')
    }

    return (data || []) as PreferenciaNotificacaoItem[]
  },

  async atualizarPreferenciasNotificacoes(
    payload: Array<{ canal: string; tipo: string; ativo: boolean }> | { canal: string; tipo: string; ativo: boolean }
  ): Promise<boolean> {
    const { data, error } = await supabase.rpc('atualizar_preferencias_notificacoes', {
      payload
    })

    if (error) {
      console.error('Erro ao atualizar preferências de notificações:', error)
      throw new Error(error.message || 'Erro ao salvar preferências.')
    }

    return !!data
  },

  // --- AUDITORIA (Restrito a Admin) ---
  async listarLogsAuditoria(): Promise<AuditoriaEventoItem[]> {
    const { data, error } = await supabase.rpc('listar_logs_auditoria')

    if (error) {
      console.error('Erro ao listar logs de auditoria:', error)
      throw new Error(error.message || 'Erro ao carregar logs de auditoria.')
    }

    return (data || []) as AuditoriaEventoItem[]
  }
}
export type ConfiguracoesService = typeof configuracoesService
