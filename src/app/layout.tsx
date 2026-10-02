import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Nodal',
  description: 'Radar pessoal de estudos de tecnologia.',
}

export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  )
}
