import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'RDS Nearby',
  description: 'Find what you need around you.',
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
