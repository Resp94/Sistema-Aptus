export interface MetricasDashboard {
  saldo_em_conta: number;
  contas_receber: number;
  cobrancas_pendentes: number;
  contas_pagar: number;
  faturas_abertas: number;
  clientes_ativos: number;
  clientes_novos_mes: number;
}

export interface FluxoCaixaMes {
  mes: string;
  ano: number;
  total: number;
}

export interface LancamentoResumo {
  id: string;
  descricao: string;
  valor: number;
  tipo: 'receita' | 'despesa';
  data: string;
}

export interface ContaPagarProxima {
  id: string;
  descricao: string;
  valor: number;
  data_vencimento: string;
}

export interface ComposicaoReceita {
  categoria: string;
  percentual: number;
}
