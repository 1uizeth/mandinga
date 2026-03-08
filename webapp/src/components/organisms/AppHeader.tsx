"use client";

import Link from "next/link";
import { WalletConnectButton } from "@/components/molecules/WalletConnectButton";
import { ThemeToggle } from "@/components/molecules/ThemeToggle";

export function AppHeader() {
  return (
    <header className="sticky top-0 z-50 w-full">
      <div className="grid grid-cols-3 h-16 md:h-20 w-full items-center px-4 md:px-6 lg:px-8">
        {/* Left: empty spacer to balance the right controls */}
        <div />

        {/* Center: brand */}
        <div className="flex justify-center">
          <Link
            href="/dashboard"
            className="text-2xl md:text-3xl font-medium tracking-tight text-foreground hover:opacity-80 transition-opacity"
          >
            Mandinga
          </Link>
        </div>

        {/* Right: controls */}
        <div className="flex items-center gap-3 justify-end">
          <ThemeToggle />
          <WalletConnectButton />
        </div>
      </div>
    </header>
  );
}
