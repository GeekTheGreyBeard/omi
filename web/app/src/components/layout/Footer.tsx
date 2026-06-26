'use client';

import { Twitter, Linkedin, Github } from 'lucide-react';
import Image from 'next/image';

export function Footer() {
  return (
    <footer className="w-full border-t border-solid border-zinc-800 bg-[#0B0F17] px-4 py-12 text-white md:px-12">
      <div className="mx-auto flex max-w-screen-xl flex-wrap justify-between gap-12">
        <div>
          <Image
            src="/omi-white.webp"
            alt="Omi Logo"
            width={146}
            height={64}
            className="h-auto w-[70px]"
          />
          <p className="mt-1 text-gray-500">Made in San Francisco</p>
          <a href="mailto:team@basedhardware.com" className="hover:underline">
            team@basedhardware.com
          </a>
          <div className="mt-3 flex items-center gap-3">
            <a
              href="https://x.com/based_hardware"
              target="_blank"
              rel="noopener noreferrer"
              className="text-gray-400 hover:text-white transition-colors"
            >
              <Twitter className="h-5 w-5" />
            </a>
            <a
              href="https://www.linkedin.com/company/omi-ai/"
              target="_blank"
              rel="noopener noreferrer"
              className="text-gray-400 hover:text-white transition-colors"
            >
              <Linkedin className="h-5 w-5" />
            </a>
            <a
              href="https://github.com/BasedHardware"
              target="_blank"
              rel="noopener noreferrer"
              className="text-gray-400 hover:text-white transition-colors"
            >
              <Github className="h-5 w-5" />
            </a>
          </div>
        </div>

      </div>
    </footer>
  );
}
