import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'RDS Nearby',
  description: 'जो चाहिए, पहले अपने आस-पास देखो।',
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="hi">
      <body>{children}</body>
    </html>
  );
}
