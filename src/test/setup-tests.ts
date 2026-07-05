/**
 * Setup global do Vitest para testes de componentes (jsdom).
 * Aplica os matchers extras do jest-dom (toBeInTheDocument, toHaveFocus, etc.)
 * a todas as suítes, incluindo as que rodam em ambiente 'node' (onde o import
 * é inofensivo pois nenhum matcher chega a ser usado).
 */
import '@testing-library/jest-dom/vitest'
