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
