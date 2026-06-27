import React, { useEffect } from 'react';

interface ToastProps {
  message: string;
  type: 'success' | 'error';
  onClose: () => void;
}

export const Toast: React.FC<ToastProps> = ({ message, type, onClose }) => {
  useEffect(() => {
    const isReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const duration = isReducedMotion ? 100 : 3500;

    const timer = setTimeout(() => {
      onClose();
    }, duration);

    return () => clearTimeout(timer);
  }, [onClose]);

  const bgStyle = type === 'error' ? 'var(--danger)' : 'var(--fg)';
  const colorStyle = type === 'error' ? '#ffffff' : 'var(--bg)';

  return (
    <div
      role="alert"
      aria-live="polite"
      className="login-toast show"
      style={{
        background: bgStyle,
        color: colorStyle,
        position: 'fixed',
        bottom: '24px',
        left: '50%',
        transform: 'translateX(-50%) translateY(0)',
        opacity: 1,
        pointerEvents: 'all',
        transition: 'all 0.35s ease',
        zIndex: 1001,
        fontFamily: 'var(--font-ui)',
        fontSize: '14px',
        padding: '10px 20px',
        borderRadius: 'var(--radius-sm)',
        boxShadow: 'var(--elev-raised)',
      }}
    >
      {message}
    </div>
  );
};
