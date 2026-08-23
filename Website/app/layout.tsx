import type { Metadata } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
});

const geistMono = Geist_Mono({
  variable: '--font-geist-mono',
  subsets: ['latin'],
});

const assetBasePath = process.env.GITHUB_PAGES === 'true' ? '/Talkmore' : '';
const talkmoreIcon = `${assetBasePath}/talkmore-icon.png`;

export const metadata: Metadata = {
  metadataBase: new URL('https://mithulram.github.io/Talkmore/'),
  title: 'Talkmore — Your voice, already written',
  description: 'Fast, private push-to-talk dictation for Apple silicon Macs. Hold fn, speak, and release to insert clean text anywhere.',
  keywords: ['macOS dictation', 'push to talk', 'on-device speech recognition', 'Apple silicon', 'open source'],
  authors: [{ name: 'Talkmore contributors' }],
  icons: { icon: talkmoreIcon, apple: talkmoreIcon },
  openGraph: {
    type: 'website',
    title: 'Talkmore — Your voice, already written',
    description: 'Fast, private, open-source push-to-talk dictation for Mac.',
    images: [{ url: talkmoreIcon, width: 1254, height: 1254, alt: 'Talkmore app icon' }],
  },
  twitter: {
    card: 'summary',
    title: 'Talkmore — Your voice, already written',
    description: 'Fast, private, open-source push-to-talk dictation for Mac.',
    images: [talkmoreIcon],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
