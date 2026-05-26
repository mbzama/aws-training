import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'SQS DLQ Demo',
  description: 'AWS SQS Dead Letter Queue demonstration with Next.js',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body style={{ fontFamily: 'monospace', padding: '2rem', background: '#0f172a', color: '#e2e8f0' }}>
        {children}
      </body>
    </html>
  );
}
