import { supabase } from './supabase';
import type {
  MetricasDashboard,
  FluxoCaixaMes,
  LancamentoResumo,
  ContaPagarProxima,
  ComposicaoReceita,
} from '../types/dashboard';

export const dashboardService = {
  async obterMetricasDashboard(): Promise<MetricasDashboard> {
    const { data, error } = await supabase.rpc('obter_metricas_dashboard');
    if (error) throw error;
    return data && data.length > 0
      ? data[0]
      : {
          saldo_em_conta: 0,
          contas_receber: 0,
          cobrancas_pendentes: 0,
          contas_pagar: 0,
          faturas_abertas: 0,
          clientes_ativos: 0,
          clientes_novos_mes: 0,
        };
  },

  async obterFluxoCaixaMensal(meses: number = 6): Promise<FluxoCaixaMes[]> {
    const { data, error } = await supabase.rpc('obter_fluxo_caixa_mensal', {
      p_meses: meses,
    });
    if (error) throw error;
    return data ?? [];
  },

  async listarUltimosLancamentos(limite: number = 5): Promise<LancamentoResumo[]> {
    const { data, error } = await supabase.rpc('listar_ultimos_lancamentos', {
      p_limite: limite,
    });
    if (error) throw error;
    return data ?? [];
  },

  async listarContasPagarProximas(dias: number = 7): Promise<ContaPagarProxima[]> {
    const { data, error } = await supabase.rpc('listar_contas_pagar_proximas', {
      p_dias: dias,
    });
    if (error) throw error;
    return data ?? [];
  },

  async obterComposicaoReceita(): Promise<ComposicaoReceita[]> {
    const { data, error } = await supabase.rpc('obter_composicao_receita');
    if (error) throw error;
    return data ?? [];
  },
};
