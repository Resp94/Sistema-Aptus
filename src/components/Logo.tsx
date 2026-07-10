import { useState } from 'react'

type LogoSize = 'sm' | 'md' | 'lg'

interface LogoProps {
  /** Tamanho pré-definido: sm=28px, md=36px, lg=48px */
  size?: LogoSize
  /** Classe CSS adicional para o <img> */
  className?: string
  /** Exibe o texto "Aptus Flow" ao lado do símbolo */
  showText?: boolean
  /** Classe CSS para o texto */
  textClassName?: string
}

const SIZE_MAP: Record<LogoSize, number> = {
  sm: 28,
  md: 36,
  lg: 48,
}

/**
 * Logo Aptus Flow — símbolo vetorial com fallback PNG.
 *
 * Estratégia: SVG primeiro (sharp em qualquer resolução), PNG como fallback.
 * O SVG `simbolo-aptus-flow.svg` é o símbolo puro;
 * para o wordmark completo, o texto "Aptus Flow" é renderizado como <span>.
 */
export function Logo({ size = 'md', className, showText = true, textClassName }: LogoProps) {
  const [erroSvg, setErroSvg] = useState(false)

  const dimensao = SIZE_MAP[size]

  const imgElement = erroSvg ? (
    <img
      src="/android-chrome-192x192.png"
      alt="Aptus Flow"
      height={dimensao}
      width={dimensao}
      className={className}
      style={{ objectFit: 'contain', flexShrink: 0 }}
      loading="eager"
    />
  ) : (
    <img
      src="/simbolo-aptus-flow.svg"
      alt="Aptus Flow"
      height={dimensao}
      width={dimensao}
      className={className}
      style={{ objectFit: 'contain', flexShrink: 0 }}
      loading="eager"
      onError={() => setErroSvg(true)}
    />
  )

  if (!showText) return imgElement

  return (
    <>
      {imgElement}
      <span className={textClassName}>ptus Flow</span>
    </>
  )
}
