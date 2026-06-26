'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';
import Image from 'next/image';
import { useRouter } from 'next/navigation';

interface LoginPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

export function LoginPanel({ isOpen, onClose }: LoginPanelProps) {
  const router = useRouter();

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop with blur */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50"
            onClick={onClose}
          />

          {/* Panel - slides in from right */}
          <motion.div
            initial={{ x: '100%', opacity: 0.8 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ x: '100%', opacity: 0.8 }}
            transition={{ type: 'spring', damping: 30, stiffness: 300 }}
            className={cn(
              'fixed right-0 top-0 h-full z-50',
              'w-full sm:w-[420px]',
              'bg-[#0B0F17] border-l border-white/10',
              'flex flex-col shadow-2xl'
            )}
          >
            {/* Subtle purple glow at top */}
            <div className="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-purple-primary/50 to-transparent" />

            {/* Close button */}
            <div className="absolute top-4 right-4 z-10">
              <button
                onClick={onClose}
                className="p-2 rounded-lg bg-white/5 hover:bg-white/10 transition-colors"
                aria-label="Close"
              >
                <X className="w-5 h-5 text-gray-400" />
              </button>
            </div>

            {/* Content */}
            <div className="flex-1 flex flex-col items-center justify-center px-8 py-12">
              <div className="w-full max-w-sm space-y-8">
                {/* Logo and heading */}
                <div className="text-center">
                  <div className="flex justify-center mb-6">
                    <Image
                      src="/omi-white.webp"
                      alt="Omi"
                      width={120}
                      height={48}
                      className="h-12 w-auto"
                    />
                  </div>
                  <h2 className="text-2xl font-semibold text-white mb-2">
                    Welcome back
                  </h2>
                  <p className="text-gray-400 text-sm">
                    Pair your Omi device to access the portal
                  </p>
                </div>

                {/* Sign in button */}
                <div className="space-y-3">
                  <button
                    onClick={() => {
                      onClose();
                      router.push('/pair');
                    }}
                    className={cn(
                      'w-full flex items-center justify-center gap-3 px-4 py-3.5 rounded-xl',
                      'bg-white text-gray-900 font-medium',
                      'hover:bg-gray-100 transition-all',
                      'shadow-lg shadow-white/5'
                    )}
                  >
                    Pair or log in
                  </button>
                </div>
              </div>
            </div>

            {/* Bottom gradient accent */}
            <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-purple-primary/5 to-transparent pointer-events-none" />
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
