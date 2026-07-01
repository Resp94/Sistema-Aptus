export interface ConfiguracaoEmpresa {
  id: string
  razao_social: string
  documento: string
  email: string
  telefone: string
  endereco: string
  idioma: string
  formato_data: string
  moeda: string
  inicio_ano_fiscal: string
  dia_vencimento_padrao: number
  percentual_multa_atraso: number
  cobranca_automatica_ativa: boolean
}

export interface UsuarioConfigItem {
  usuario_id: string
  nome: string
  email: string
  perfil_acesso: string
  status: 'Ativo' | 'Inativo'
  departamento: string | null
}

export interface PreferenciaNotificacaoItem {
  id: string
  perfil_id: string
  canal: 'Email' | 'Sistema'
  tipo: 'Lembretes' | 'Alertas' | 'Relatorio semanal' | 'Cobrancas'
  ativo: boolean
}

export interface AuditoriaEventoItem {
  id: string
  evento: string
  usuario_nome: string
  ip_address: string
  detalhes: string
  criado_em: string
}
