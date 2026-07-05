'use client';

import { useState, useEffect } from 'react';

export function BetaRibbon() {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  // Don't render on server to avoid hydration issues
  if (!mounted) return null;

  // Don't show on mobile (overlay handles it)
  if (typeof window !== 'undefined' && window.innerWidth < 1024) return null;

  return (
    <>
      {/* Beta ribbon */}
      <div className="fixed top-0 right-0 z-[9998] overflow-hidden pointer-events-none w-32 h-32">
        <div
          className="absolute top-6 -right-8 w-36 text-center py-1.5 bg-purple-primary text-white text-xs font-semibold uppercase tracking-wider rotate-45 shadow-lg"
        >
          Beta
        </div>
      </div>
    </>
  );
}
