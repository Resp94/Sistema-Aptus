import React, { useState, useEffect, useRef } from 'react';
import { authService } from '../services/auth.service';
import { Toast } from '../components/ui/Toast';
import './Login.css';

export const Login: React.FC = () => {
  // Login Form State
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(true);
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [rateLimited, setRateLimited] = useState(false);

  // Form Validation State
  const [emailInvalid, setEmailInvalid] = useState(false);
  const [emailError, setEmailError] = useState('');
  const [passwordInvalid, setPasswordInvalid] = useState(false);
  const [passwordError, setPasswordError] = useState('');

  // Forgot Password Modal State
  const [modalOpen, setModalOpen] = useState(false);
  const [resetEmail, setResetEmail] = useState('');
  const [modalLoading, setModalLoading] = useState(false);
  const modalEmailRef = useRef<HTMLInputElement>(null);
  const triggerButtonRef = useRef<HTMLButtonElement>(null);

  // Toast Notification State
  const [toastMessage, setToastMessage] = useState('');
  const [toastType, setToastType] = useState<'success' | 'error'>('success');

  // Check if redirected from reset password success
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get('reset_success') === 'true') {
      setToastType('success');
      setToastMessage('Senha redefinida com sucesso. Faça login com sua nova senha.');
      // Remove query param without reload
      window.history.replaceState({}, document.title, window.location.pathname);
    }
  }, []);

  // Manage focus restoration for accessibility on modal close
  const openModal = () => {
    setResetEmail('');
    setModalOpen(true);
    setTimeout(() => {
      if (modalEmailRef.current) {
        modalEmailRef.current.focus();
      }
    }, 50);
  };

  const closeModal = () => {
    setModalOpen(false);
    if (triggerButtonRef.current) {
      triggerButtonRef.current.focus();
    }
  };

  // Close modal on Escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && modalOpen) {
        closeModal();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [modalOpen]);

  const validateEmail = (emailStr: string): boolean => {
    const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return regex.test(emailStr);
  };

  const handleLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (rateLimited || loading) return;

    // Reset validations
    setEmailInvalid(false);
    setPasswordInvalid(false);

    let valid = true;

    // Validate email
    if (!email.trim()) {
      setEmailInvalid(true);
      setEmailError('Informe seu e-mail.');
      valid = false;
    } else if (!validateEmail(email.trim())) {
      setEmailInvalid(true);
      setEmailError('Informe um e-mail válido.');
      valid = false;
    }

    // Validate password
    if (!password) {
      setPasswordInvalid(true);
      setPasswordError('Informe sua senha.');
      valid = false;
    } else if (password.length < 8) {
      setPasswordInvalid(true);
      setPasswordError('A senha deve ter no mínimo 8 caracteres.');
      valid = false;
    }

    if (!valid) return;

    setLoading(true);
    setRateLimited(true);

    // Rate limiting: re-enable after 3 seconds (FR-010)
    setTimeout(() => {
      setRateLimited(false);
    }, 3000);

    try {
      // Entrar usando o e-mail e senha formatados
      const perfil = await authService.signIn(email, password);

      setToastType('success');
      setToastMessage(`Login realizado com sucesso! Bem-vindo, ${perfil.nome}.`);

      // Redireciona com base no perfil de acesso após breve delay
      setTimeout(() => {
        switch (perfil.perfil_acesso) {
          case 'Administrador':
          case 'Financeiro':
            window.location.href = '/dashboard.html';
            break;
          case 'Projetos':
          case 'Técnico':
            window.location.href = '/projetos.html';
            break;
          case 'Comercial':
            window.location.href = '/clientes.html';
            break;
          default:
            window.location.href = '/dashboard.html';
        }
      }, 1000);

    } catch (err: any) {
      setToastType('error');
      setToastMessage(err.message || 'Serviço de autenticação temporariamente indisponível.');
      setLoading(false);
    }
  };

  const handleSendResetLink = async () => {
    if (!resetEmail.trim() || !validateEmail(resetEmail.trim())) {
      setToastType('error');
      setToastMessage('Informe um e-mail válido.');
      return;
    }

    setModalLoading(true);
    try {
      await authService.resetPassword(resetEmail);
      
      // Mensagem genérica por privacidade (SC-005)
      setToastType('success');
      setToastMessage(`Enviamos um link de redefinição para ${resetEmail.trim()} – verifique sua caixa de entrada.`);
      closeModal();
    } catch (err: any) {
      // Mesmo em caso de erro no envio, mantemos a mensagem amigável ou reportamos problema de serviço
      setToastType('error');
      setToastMessage(err.message || 'Erro ao processar solicitação.');
    } finally {
      setModalLoading(false);
    }
  };

  return (
    <div className="login-page">
      {/* Coluna da esquerda - Identidade visual */}
      <div className="login-brand">
        <div className="brand-name"><span className="logo-dot"></span>Aptus Flow</div>
        <p className="brand-sub">Gestão financeira inteligente para empresas de IA e automação.</p>
        
        <div className="brand-features">
          <div className="bf-label">Tudo que sua gestão precisa</div>
          
          <div className="bf-item">
            <div className="bf-icon">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline>
              </svg>
            </div>
            <span>Fluxo de caixa em tempo real com projeções inteligentes</span>
          </div>

          <div className="bf-item">
            <div className="bf-icon">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
                <path d="M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2"></path>
                <circle cx="9" cy="7" r="4"></circle>
                <path d="M22 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"></path>
              </svg>
            </div>
            <span>Gestão unificada de clientes, propostas e contratos</span>
          </div>

          <div className="bf-item">
            <div className="bf-icon">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="3" width="7" height="7"></rect>
                <rect x="14" y="3" width="7" height="7"></rect>
                <rect x="14" y="14" width="7" height="7"></rect>
                <rect x="3" y="14" width="7" height="7"></rect>
              </svg>
            </div>
            <span>Projetos organizados em Kanban com acompanhamento visual</span>
          </div>

          <div className="bf-item">
            <div className="bf-icon">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
                <rect x="1" y="4" width="22" height="16" rx="2"></rect>
                <path d="M1 10h22"></path>
              </svg>
            </div>
            <span>Cobranças automatizadas com boleto, Pix e lembretes</span>
          </div>
        </div>
      </div>

      {/* Coluna da direita - Formulário */}
      <div className="login-form-area">
        <div className="mobile-brand-bar">
          <span><span style={{ color: 'var(--accent)' }}>●</span> Aptus Flow</span>
        </div>

        <div className="form-header">
          <h1>Bem-vindo de volta</h1>
          <p>Faça login para acessar o painel financeiro da sua empresa.</p>
        </div>

        <form className="login-form" onSubmit={handleLoginSubmit} noValidate>
          {/* Email field */}
          <div className="field">
            <label htmlFor="email">E-mail</label>
            <input
              id="email"
              className="input"
              type="email"
              placeholder="seu@email.com"
              required
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                setEmailInvalid(false);
              }}
              aria-invalid={emailInvalid ? 'true' : 'false'}
              autoComplete="email"
            />
            {emailInvalid && (
              <div className="field-error" style={{ opacity: 1, maxHeight: '24px' }}>
                {emailError}
              </div>
            )}
          </div>

          {/* Password field */}
          <div className="field">
            <label htmlFor="password">Senha</label>
            <div className="pw-wrapper">
              <input
                id="password"
                className="input"
                type={showPassword ? 'text' : 'password'}
                placeholder="Insira sua senha"
                required
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value);
                  setPasswordInvalid(false);
                }}
                aria-invalid={passwordInvalid ? 'true' : 'false'}
                autoComplete="current-password"
              />
              <button
                className="pw-toggle"
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                aria-label={showPassword ? 'Esconder senha' : 'Mostrar senha'}
                title={showPassword ? 'Esconder senha' : 'Mostrar senha'}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
                  {showPassword ? (
                    <>
                      <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                      <line x1="1" y1="1" x2="23" y2="23" />
                    </>
                  ) : (
                    <>
                      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                      <circle cx="12" cy="12" r="3" />
                    </>
                  )}
                </svg>
              </button>
            </div>
            {passwordInvalid && (
              <div className="field-error" style={{ opacity: 1, maxHeight: '24px' }}>
                {passwordError}
              </div>
            )}
          </div>

          {/* Remember me checkbox */}
          <div className="remember-row">
            <input
              type="checkbox"
              id="remember"
              checked={remember}
              onChange={(e) => setRemember(e.target.checked)}
            />
            <label htmlFor="remember">Lembrar de mim</label>
          </div>

          {/* Form actions */}
          <div className="form-footer">
            <button
              ref={triggerButtonRef}
              className="forgot-link"
              type="button"
              onClick={openModal}
            >
              Esqueci a senha
            </button>
            <button
              className={`btn btn-primary ${loading ? 'btn-loading' : ''}`}
              type="submit"
              disabled={loading || rateLimited}
            >
              Acessar painel
            </button>
          </div>
        </form>
      </div>

      {/* Forgot Password Modal */}
      {modalOpen && (
        <div
          className="modal-overlay open"
          onClick={(e) => {
            if (e.target === e.currentTarget) closeModal();
          }}
        >
          <div className="modal-content">
            <h2>Recuperar acesso</h2>
            <p>Informe seu e-mail cadastrado para receber o link de redefinição de senha.</p>
            <div className="field" style={{ marginBottom: 'var(--space-5)' }}>
              <label htmlFor="reset-email">E-mail</label>
              <input
                ref={modalEmailRef}
                id="reset-email"
                className="input"
                type="email"
                placeholder="seu@email.com"
                required
                value={resetEmail}
                onChange={(e) => setResetEmail(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleSendResetLink();
                }}
              />
            </div>
            <div className="modal-actions">
              <button
                className="btn btn-secondary"
                onClick={closeModal}
                disabled={modalLoading}
              >
                Cancelar
              </button>
              <button
                className={`btn btn-primary ${modalLoading ? 'btn-loading' : ''}`}
                onClick={handleSendResetLink}
                disabled={modalLoading}
              >
                Enviar link
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Toast Messages */}
      {toastMessage && (
        <Toast
          message={toastMessage}
          type={toastType}
          onClose={() => setToastMessage('')}
        />
      )}
    </div>
  );
};
export default Login;
