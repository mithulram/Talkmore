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
const socialImage = 'https://mithulram.github.io/Talkmore/talkmore-icon.png';

export const metadata: Metadata = {
  metadataBase: new URL('https://mithulram.github.io/Talkmore/'),
  title: 'Talkmore — Your voice, already written',
  description: 'Fast, private English push-to-talk dictation for Mac with automatic on-device recognition. Hold fn, speak, and release to insert clean text anywhere.',
  keywords: ['macOS dictation', 'English speech to text', 'push to talk', 'on-device speech recognition', 'Parakeet Unified', 'open source'],
  authors: [{ name: 'Talkmore contributors' }],
  icons: { icon: talkmoreIcon, apple: talkmoreIcon },
  openGraph: {
    type: 'website',
    title: 'Talkmore — Your voice, already written',
    description: 'Fast, accurate, private English push-to-talk dictation for Mac.',
    images: [{ url: socialImage, width: 1254, height: 1254, alt: 'Talkmore app icon' }],
  },
  twitter: {
    card: 'summary',
    title: 'Talkmore — Your voice, already written',
    description: 'Fast, accurate, private English push-to-talk dictation for Mac.',
    images: [socialImage],
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
