import React, { useState } from 'react';
import { supabase } from '../services/supabase';
import { authService } from '../services/auth.service';
import { Toast } from '../components/ui/Toast';
import { Logo } from '../components/Logo';

export const ResetPassword: React.FC = () => {
  const [password, setPassword] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const [passwordInvalid, setPasswordInvalid] = useState(false);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  
  const [toastMessage, setToastMessage] = useState('');
  const [toastType, setToastType] = useState<'success' | 'error'>('success');

  const validatePasswordComplexity = (pw: string): string | null => {
    if (pw.length < 8) {
      return 'A senha deve ter no mínimo 8 caracteres.';
    }
    if (!/[A-Z]/.test(pw)) {
      return 'A senha deve conter pelo menos uma letra maiúscula.';
    }
    if (!/[a-z]/.test(pw)) {
      return 'A senha deve conter pelo menos uma letra minúscula.';
    }
    if (!/[0-9]/.test(pw)) {
      return 'A senha deve conter pelo menos um número.';
    }
    if (!/[!@#$%^&*(),.?":{}|<>]/.test(pw)) {
      return 'A senha deve conter pelo menos um caractere especial (ex: !, @, #, $, etc.).';
    }
    const commonPasswords = ['12345678', 'password', 'password123', 'senha123', 'admin123'];
    if (commonPasswords.includes(pw.toLowerCase())) {
      return 'Esta senha é muito comum. Escolha uma senha mais forte.';
    }
    return null;
  };

  const handleReset = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordInvalid(false);
    setPasswordError('');

    // Validação
    const errorMsg = validatePasswordComplexity(password);
    if (errorMsg) {
      setPasswordInvalid(true);
      setPasswordError(errorMsg);
      return;
    }

    setLoading(true);

    try {
      // Atualiza a senha no Supabase Auth usando a sessão temporária do hash
      const { error } = await supabase.auth.updateUser({ password: password });
      
      if (error) {
        console.error('Erro ao atualizar senha:', error);
        setToastType('error');
        setToastMessage('Link de redefinição expirado ou inválido. Solicite um novo link.');
        return;
      }

      // Sucesso: registra evento de auditoria se possível
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
          await supabase.rpc('registrar_evento_auditoria', {
            p_evento: 'senha_alterada',
            p_ip_origem: '0.0.0.0',
            p_user_agent: window.navigator.userAgent
          });
        }
      } catch (ae) {
        console.error('Erro ao registrar auditoria de senha:', ae);
      }

      // Desloga o usuário para forçar reautenticação
      await authService.signOut();

      setToastType('success');
      setToastMessage('Senha redefinida com sucesso. Faça login com sua nova senha.');
      
      // Limpa o hash da URL e redireciona após 3s
      setTimeout(() => {
        window.location.href = '/login?reset_success=true';
      }, 3000);

    } catch (err: any) {
      setToastType('error');
      setToastMessage(err.message || 'Erro ao redefinir a senha. Tente novamente.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-brand">
        <div className="brand-logo">
          <Logo size="lg" showText={false} />
        </div>
        <div className="brand-name">Aptus Flow</div>
        <p className="brand-sub">Gestão financeira inteligente para empresas de IA e automação.</p>
      </div>

      <div className="login-form-area">
        <div className="mobile-brand-bar">
          <Logo size="sm" showText={false} className="mobile-brand-logo" />
          <span><span style={{ color: 'var(--accent)' }}>●</span> Aptus Flow</span>
        </div>

        <div className="form-header">
          <h1>Nova senha</h1>
          <p>Defina sua nova senha de acesso.</p>
        </div>

        <form className="login-form" onSubmit={handleReset} noValidate>
          <div className="field">
            <label htmlFor="password">Nova Senha</label>
            <div className="pw-wrapper">
              <input
                id="password"
                className="input"
                type={showPassword ? 'text' : 'password'}
                placeholder="Insira sua nova senha"
                required
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value);
                  setPasswordInvalid(false);
                }}
                aria-invalid={passwordInvalid ? 'true' : 'false'}
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
              <div className="field-error" style={{ opacity: 1, maxHeight: '50px' }}>
                {passwordError}
              </div>
            )}
          </div>

          <div className="form-footer" style={{ marginTop: 'var(--space-6)', justifyContent: 'flex-end' }}>
            <button
              className={`btn btn-primary ${loading ? 'btn-loading' : ''}`}
              type="submit"
              disabled={loading}
            >
              Definir nova senha
            </button>
          </div>
        </form>
      </div>

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
export default ResetPassword;
