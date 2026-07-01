// Tipos comuns compartilhados para a Feature 005 e demais domínios do Aptus Flow

export type StatusCobranca = 'Pendente' | 'Pago' | 'Vencido' | 'Cancelado';
export type StatusProposta = 'Rascunho' | 'Enviado' | 'Em análise' | 'Aprovado' | 'Rejeitado';
export type StatusContrato = 'Vigente' | 'Vencimento próximo' | 'Encerrado';
export type StatusBoleto = 'Não configurado' | 'Pendente' | 'Emitido' | 'Falhou';
export type StatusLembrete = 'Não enviado' | 'Pendente' | 'Enviado' | 'Falhou';
export type StatusMembro = 'Disponível' | 'Alocado' | 'Férias' | 'Ausente';
export type StatusExportacao = 'Pendente' | 'Pronto' | 'Falhou' | 'Indisponível';

export interface ApiError {
  code: string;
  message: string;
  details?: string;
}

export interface OptionSelect {
  value: string;
  label: string;
}
