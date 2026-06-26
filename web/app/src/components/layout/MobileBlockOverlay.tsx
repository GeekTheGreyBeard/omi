'use client';

import { useState, useEffect, useRef } from 'react';
import { usePathname } from 'next/navigation';
import Image from 'next/image';
import { X } from 'lucide-react';

// Paths that should completely bypass mobile detection
const BYPASS_MOBILE_CHECK_PATHS = [
  '/record/popout',
  '/record/popout/transcript',
];

// Debounce delay for resize detection (ms)
const RESIZE_DEBOUNCE_MS = 500;

// Session storage key for dismissal
const DISMISSED_KEY = 'omi_mobile_overlay_dismissed';

export function MobileBlockOverlay() {
  const pathname = usePathname();
  const [isMobile, setIsMobile] = useState(false);
  const [mounted, setMounted] = useState(false);
  const [isDismissed, setIsDismissed] = useState(false);
  const resizeTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Check if current path should bypass mobile detection entirely
  const shouldBypass = BYPASS_MOBILE_CHECK_PATHS.some(path => pathname?.startsWith(path));

  useEffect(() => {
    setMounted(true);

    // Check if already dismissed this session
    if (typeof window !== 'undefined') {
      const dismissed = sessionStorage.getItem(DISMISSED_KEY);
      if (dismissed === 'true') {
        setIsDismissed(true);
      }
    }

    // Check viewport width with debounce
    const checkMobile = () => {
      // Clear any pending timeout
      if (resizeTimeoutRef.current) {
        clearTimeout(resizeTimeoutRef.current);
      }

      // Only set mobile state after debounce delay
      resizeTimeoutRef.current = setTimeout(() => {
        setIsMobile(window.innerWidth < 768);
      }, RESIZE_DEBOUNCE_MS);
    };

    // Initial check without debounce
    setIsMobile(window.innerWidth < 768);

    window.addEventListener('resize', checkMobile);

    return () => {
      window.removeEventListener('resize', checkMobile);
      if (resizeTimeoutRef.current) {
        clearTimeout(resizeTimeoutRef.current);
      }
    };
  }, []);

  const handleDismiss = () => {
    setIsDismissed(true);
    if (typeof window !== 'undefined') {
      sessionStorage.setItem(DISMISSED_KEY, 'true');
    }
  };

  // Don't render anything on server, if not mobile, if dismissed, or if on bypass path
  if (!mounted || !isMobile || isDismissed || shouldBypass) return null;

  return (
    <div className="fixed inset-0 z-[9999] bg-bg-primary flex flex-col items-center justify-center p-6">
      {/* Dismiss button - top right corner */}
      <button
        onClick={handleDismiss}
        className="absolute top-4 right-4 z-20 p-2 bg-white/5 hover:bg-white/10 rounded-lg transition-colors"
        aria-label="Continue to web"
      >
        <X className="w-5 h-5 text-gray-400" />
      </button>

      {/* Background gradient effect */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-purple-primary/5 rounded-full blur-[120px]" />
      </div>

      {/* Main content container */}
      <div className="relative z-10 flex flex-col items-center justify-center flex-1 max-w-sm text-center">
        {/* Round logo with breathing glow */}
        <div className="relative mb-8">
          <div
            className="absolute inset-0 rounded-full bg-purple-primary/20 blur-xl animate-pulse"
            style={{ animationDuration: '3s' }}
          />
          <div className="w-28 h-28 relative">
            <Image
              src="/logo.png"
              alt="Omi"
              fill
              className="object-contain relative z-10 drop-shadow-[0_0_15px_rgba(139,92,246,0.3)]"
              priority
            />
          </div>
        </div>

        {/* Message */}
        <h1 className="text-2xl font-semibold text-text-primary mb-3">
          Omi Web is optimized for desktop.
        </h1>
        <p className="text-text-tertiary mb-8">
          Pair or log in with your Omi device to continue.
        </p>

        <button
          onClick={handleDismiss}
          className="inline-flex items-center gap-3 bg-white text-black px-6 py-3 rounded-xl font-medium hover:bg-gray-100 transition-colors mb-4"
        >
          Pair or log in
        </button>

        {/* Continue to web button */}
        <button
          onClick={handleDismiss}
          className="text-text-tertiary hover:text-text-secondary transition-colors text-sm"
        >
          Continue to web anyway
        </button>
      </div>

      {/* Bottom section with logo and links */}
      <div className="relative z-10 pb-8 flex flex-col items-center gap-4">
        <Image
          src="/omi-white.webp"
          alt="Omi"
          width={60}
          height={24}
          priority
        />
      </div>
    </div>
  );
}
