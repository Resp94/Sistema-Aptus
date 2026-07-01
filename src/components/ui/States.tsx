import React from 'react'

interface LoadingStateProps {
  message?: string
}

export const LoadingState: React.FC<LoadingStateProps> = ({ message = 'Carregando dados...' }) => {
  return (
    <div className="state-container loading-state">
      <div className="spinner" role="progressbar" aria-label={message}></div>
      <p>{message}</p>
    </div>
  )
}

interface EmptyStateProps {
  title?: string
  description?: string
  action?: {
    label: string
    onClick: () => void
  }
}

export const EmptyState: React.FC<EmptyStateProps> = ({
  title = 'Nenhum registro encontrado',
  description = 'Não há dados cadastrados nesta seção ou para os filtros selecionados.',
  action
}) => {
  return (
    <div className="state-container empty-state">
      <svg className="state-icon" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
        <circle cx="12" cy="12" r="10" />
        <line x1="8" y1="12" x2="16" y2="12" />
      </svg>
      <h3 className="state-title">{title}</h3>
      <p className="state-desc">{description}</p>
      {action && (
        <button className="btn btn-primary" onClick={action.onClick}>
          {action.label}
        </button>
      )}
    </div>
  )
}

interface ErrorStateProps {
  title?: string
  message?: string
  onRetry?: () => void
}

export const ErrorState: React.FC<ErrorStateProps> = ({
  title = 'Ops! Algo deu errado',
  message = 'Ocorreu um erro ao carregar os dados. Por favor, tente novamente.',
  onRetry
}) => {
  return (
    <div className="state-container error-state">
      <svg className="state-icon" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
        <polygon points="7.86 2 16.14 2 22 7.86 22 16.14 16.14 22 7.86 22 2 16.14 2 7.86 7.86 2" />
        <line x1="12" y1="8" x2="12" y2="12" />
        <line x1="12" y1="16" x2="12.01" y2="16" />
      </svg>
      <h3 className="state-title">{title}</h3>
      <p className="state-desc">{message}</p>
      {onRetry && (
        <button className="btn btn-secondary" onClick={onRetry}>
          Tentar novamente
        </button>
      )}
    </div>
  )
}

interface IntegrationPendingStateProps {
  message?: string
  status?: string
}

export const IntegrationPendingState: React.FC<IntegrationPendingStateProps> = ({
  message = 'Serviço externo temporariamente indisponível.',
  status = 'Não configurado'
}) => {
  return (
    <div className="integration-pending-banner">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
        <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
        <line x1="12" y1="9" x2="12" y2="13" />
        <line x1="12" y1="17" x2="12.01" y2="17" />
      </svg>
      <span className="integration-msg"><strong>{status}</strong>: {message}</span>
    </div>
  )
}
