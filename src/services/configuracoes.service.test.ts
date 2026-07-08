import { afterEach, describe, expect, it } from 'vitest'
import { configuracoesService } from './configuracoes.service'
import { mockSupabaseRpc, restaurarMocksRpc } from './rpc-test-utils'

describe('configuracoesService.obterConfiguracoesEmpresa', () => {
  afterEach(() => {
    restaurarMocksRpc()
  })

  it('retorna uma estrutura inicial utilizável no primeiro acesso quando a RPC ainda não possui linha em configuracoes_empresa', async () => {
    mockSupabaseRpc('obter_configuracoes_empresa', null)

    const res = await configuracoesService.obterConfiguracoesEmpresa()

    expect(res).toEqual({
      id: 'config_unica',
      razao_social: '',
      documento: '',
      email: '',
      telefone: '',
      endereco: '',
      idioma: 'pt-BR',
      formato_data: 'dd/MM/yyyy',
      moeda: 'BRL',
      inicio_ano_fiscal: '',
      dia_vencimento_padrao: 5,
      percentual_multa_atraso: 2,
      cobranca_automatica_ativa: false,
    })
  })
})

describe('configuracoesService.criarUsuarioConfiguracoes', () => {
  afterEach(() => {
    restaurarMocksRpc()
  })

  it('chama a RPC criar_usuario_configuracoes com o payload informado pelo administrador', async () => {
    const payload = {
      nome: 'Novo Usuário',
      email: 'novo@aptusflow.local',
      senha_temporaria: 'SenhaTemp123!',
      perfil_acesso: 'Financeiro' as const,
      departamento: 'Financeiro',
      status: 'Ativo' as const,
    }
    const mockRpc = mockSupabaseRpc('criar_usuario_configuracoes', true)

    const res = await configuracoesService.criarUsuarioConfiguracoes(payload)

    expect(mockRpc).toHaveBeenCalledWith('criar_usuario_configuracoes', { payload })
    expect(res).toBe(true)
  })
})
