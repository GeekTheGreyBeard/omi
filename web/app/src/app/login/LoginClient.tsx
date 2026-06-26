'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Image from 'next/image';
import { motion } from 'framer-motion';
import { useAuth } from '@/components/auth/AuthProvider';
import { cn } from '@/lib/utils';
import { MixpanelManager } from '@/lib/analytics/mixpanel';

export function LoginClient() {
  const { user, loading } = useAuth();
  const router = useRouter();

  // Track page view
  useEffect(() => {
    MixpanelManager.pageView('Login');
  }, []);

  // Redirect to conversations if already logged in
  useEffect(() => {
    if (!loading && user) {
      router.push('/conversations');
    }
  }, [user, loading, router]);

  // Show loading state while checking auth
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-bg-primary">
        <div className="w-16 h-16 border-4 border-purple-primary/30 border-t-purple-primary rounded-full animate-spin" />
      </div>
    );
  }

  // Don't show login if user is already logged in (will redirect)
  if (user) {
    return null;
  }

  return (
    <div className="min-h-screen relative overflow-hidden bg-black">
      {/* Background Image with subtle floating animation */}
      <motion.div
        initial={{ opacity: 0, scale: 1.05 }}
        animate={{
          opacity: 1,
          scale: 1,
          y: [0, -8, 0],
        }}
        transition={{
          opacity: { duration: 1.2, ease: 'easeOut' },
          scale: { duration: 1.2, ease: 'easeOut' },
          y: {
            duration: 9,
            repeat: Infinity,
            ease: 'easeInOut',
            delay: 1.5
          }
        }}
        className="absolute inset-0 z-0"
      >
        <Image
          src="/login-bg.png"
          alt="Omi Product"
          fill
          className="object-cover"
          priority
        />
        {/* Darker overlay for better contrast */}
        <div className="absolute inset-0 bg-black/55" />
      </motion.div>

      {/* Vignette effect - darkens edges */}
      <div
        className="absolute inset-0 z-10 pointer-events-none"
        style={{
          background: 'radial-gradient(ellipse at 50% 50%, transparent 0%, rgba(0, 0, 0, 0.4) 70%, rgba(0, 0, 0, 0.7) 100%)',
        }}
      />

      {/* Login Form (centered) */}
      <div className="relative z-20 min-h-screen flex items-center justify-center px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.3 }}
        >
          <div className="w-full max-w-sm flex flex-col items-center">
          {/* Headline */}
          <motion.h1
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, delay: 0.1 }}
            className="text-3xl font-display font-semibold text-text-primary mb-2"
          >
            Omi
          </motion.h1>

          {/* Tagline */}
          <motion.p
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, delay: 0.3 }}
            className="text-text-tertiary text-lg mb-28"
          >
            thought to action
          </motion.p>

          {/* Logo with glow and hover animation */}
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            whileHover={{ scale: 1.05, rotate: 10 }}
            transition={{ duration: 0.3 }}
            className="mb-14"
          >
            <div className="w-28 h-28 relative group">
              {/* Blue glow effect - outer */}
              <div className="absolute inset-[-20px] rounded-full bg-blue-500/30 blur-2xl group-hover:bg-blue-500/50 transition-all duration-500" />
              {/* Purple glow effect - inner */}
              <div className="absolute inset-0 rounded-full bg-purple-primary/20 blur-xl group-hover:bg-purple-primary/40 transition-all duration-500" />
              <Image
                src="/logo.png"
                alt="Omi"
                fill
                className="object-contain relative z-10 drop-shadow-[0_0_25px_rgba(59,130,246,0.6)] group-hover:drop-shadow-[0_0_35px_rgba(59,130,246,0.8)] transition-all duration-300"
                priority
              />
            </div>
          </motion.div>

          {/* Auth button */}
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, delay: 0.2 }}
            className="w-full space-y-4"
          >
            <a
              href="/pair"
              className={cn(
                'w-full flex items-center justify-center gap-3 px-6 py-4 rounded-xl',
                'bg-bg-tertiary text-text-primary font-medium border border-white/10',
                'transition-all duration-150 hover:bg-bg-quaternary hover:scale-[1.02]',
                'focus:outline-none focus-visible:ring-2 focus-visible:ring-white/50 focus-visible:ring-offset-2 focus-visible:ring-offset-bg-primary'
              )}
            >
              Pair or log in
            </a>
          </motion.div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
