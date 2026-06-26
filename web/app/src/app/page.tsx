import Image from 'next/image';
import Link from 'next/link';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Omi - Your AI Companion',
  description: 'Omi - Your AI companion that turns thoughts into action.',
  openGraph: {
    title: 'Omi - Your AI Companion',
    description: 'Omi - Your AI companion that turns thoughts into action.',
    url: '/',
    type: 'website',
    images: [
      {
        url: '/login-bg.png',
        width: 1200,
        height: 630,
        alt: 'Omi - Thought to Action',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Omi - Your AI Companion',
    description: 'Omi - Your AI companion that turns thoughts into action.',
    images: ['/login-bg.png'],
  },
};

export default function HomePage() {
  return (
    <main className="relative min-h-screen overflow-hidden bg-black text-text-primary">
      <div className="absolute inset-0 z-0">
        <Image src="/login-bg.png" alt="Omi product" fill className="object-cover" priority />
        <div className="absolute inset-0 bg-black/60" />
      </div>

      <div
        className="pointer-events-none absolute inset-0 z-10"
        style={{
          background:
            'radial-gradient(ellipse at 50% 45%, transparent 0%, rgba(0, 0, 0, 0.42) 70%, rgba(0, 0, 0, 0.75) 100%)',
        }}
      />

      <section className="relative z-20 mx-auto flex min-h-screen w-full max-w-md flex-col items-center justify-center px-5 py-10 text-center">
        <h1 className="mb-2 font-display text-3xl font-semibold text-white">Omi</h1>
        <p className="mb-24 text-lg text-text-tertiary">thought to action</p>

        <div className="relative mb-14 h-28 w-28">
          <div className="absolute inset-[-20px] rounded-full bg-blue-500/30 blur-2xl" />
          <div className="absolute inset-0 rounded-full bg-purple-primary/20 blur-xl" />
          <Image
            src="/logo.png"
            alt="Omi"
            fill
            className="relative z-10 object-contain drop-shadow-[0_0_25px_rgba(59,130,246,0.6)]"
            priority
          />
        </div>

        <div className="grid w-full gap-3 sm:grid-cols-2">
          <Link
            href="/login"
            className="flex min-h-14 items-center justify-center rounded-full border border-white/15 bg-bg-tertiary px-6 py-3 font-medium text-white transition hover:border-white/25 hover:bg-bg-quaternary focus:outline-none focus-visible:ring-2 focus-visible:ring-white/50 focus-visible:ring-offset-2 focus-visible:ring-offset-bg-primary"
          >
            Log in
          </Link>
          <Link
            href="/pair"
            className="flex min-h-14 items-center justify-center rounded-full bg-white px-6 py-3 font-medium text-black transition hover:bg-text-secondary focus:outline-none focus-visible:ring-2 focus-visible:ring-white/50 focus-visible:ring-offset-2 focus-visible:ring-offset-bg-primary"
          >
            Register
          </Link>
        </div>
      </section>
    </main>
  );
}
