import { supabase } from './supabase'
import type {
  ConfiguracaoEmpresa,
  UsuarioConfigItem,
  CriarUsuarioConfiguracoesPayload,
  PreferenciaNotificacaoItem,
  AuditoriaEventoItem
} from '../types/configuracoes'

function normalizarConfiguracaoEmpresa(
  data: Partial<ConfiguracaoEmpresa> | Partial<ConfiguracaoEmpresa>[] | null | undefined
): ConfiguracaoEmpresa {
  const item = (Array.isArray(data) ? data[0] : data) ?? {}

  return {
    id: item.id || 'config_unica',
    razao_social: item.razao_social || '',
    documento: item.documento || '',
    email: item.email || '',
    telefone: item.telefone || '',
    endereco: item.endereco || '',
    idioma: item.idioma || 'pt-BR',
    formato_data: item.formato_data || 'dd/MM/yyyy',
    moeda: item.moeda || 'BRL',
    inicio_ano_fiscal: item.inicio_ano_fiscal || '',
    dia_vencimento_padrao: item.dia_vencimento_padrao ?? 5,
    percentual_multa_atraso: item.percentual_multa_atraso ?? 2,
    cobranca_automatica_ativa: item.cobranca_automatica_ativa ?? false
  }
}

export const configuracoesService = {
  // --- CONFIGURAÇÕES DA EMPRESA (Restrito a Admin) ---
  async obterConfiguracoesEmpresa(): Promise<ConfiguracaoEmpresa> {
    const { data, error } = await supabase.rpc('obter_configuracoes_empresa')

    if (error) {
      console.error('Erro ao obter configurações da empresa:', error)
      throw new Error(error.message || 'Erro ao carregar configurações globais.')
    }

    return normalizarConfiguracaoEmpresa(data as Partial<ConfiguracaoEmpresa> | Partial<ConfiguracaoEmpresa>[] | null | undefined)
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

  async criarUsuarioConfiguracoes(payload: CriarUsuarioConfiguracoesPayload): Promise<boolean> {
    const { data, error } = await supabase.rpc('criar_usuario_configuracoes', {
      payload
    })

    if (error) {
      console.error('Erro ao criar usuário do sistema:', error)
      throw new Error(error.message || 'Erro ao cadastrar novo usuário.')
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
