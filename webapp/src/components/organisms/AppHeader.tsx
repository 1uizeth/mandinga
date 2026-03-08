"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAccount } from "wagmi";
import { cn } from "@/lib/utils";
import { WalletConnectButton } from "@/components/molecules/WalletConnectButton";
import { ThemeToggle } from "@/components/molecules/ThemeToggle";

export function AppHeader() {
  const { isConnected } = useAccount();
  const pathname = usePathname();
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 0);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className={cn(
        "sticky top-0 z-50 w-full transition-all duration-200",
        scrolled && "bg-white dark:bg-background shadow-md"
      )}
    >
      <div className="flex h-16 md:h-20 w-full items-center justify-between px-4 md:px-6 lg:px-8">
        <Link
          href="/"
          className="text-2xl md:text-3xl font-medium tracking-tight text-foreground hover:opacity-80 transition-opacity"
        >
          Mandinga
        </Link>
        <nav className="flex items-center gap-4">
          {isConnected && (
            <div className="no-scrollbar flex gap-2 overflow-x-auto">
              <Link
                href="/dashboard"
                className={cn(
                  "inline-flex h-9 shrink-0 items-center px-4 py-2 text-sm font-medium transition-all duration-200",
                  pathname === "/dashboard"
                    ? "rounded-[9px] bg-accent/10 text-foreground shadow-[0_0_0_1px] shadow-accent"
                    : "rounded-lg text-muted-foreground hover:rounded-[9px] hover:shadow-[0_0_0_1px] hover:shadow-accent hover:text-foreground"
                )}
                aria-current={pathname === "/dashboard" ? "page" : undefined}
              >
                Dashboard
              </Link>
              <Link
                href="/circles"
                className={cn(
                  "inline-flex h-9 shrink-0 items-center px-4 py-2 text-sm font-medium transition-all duration-200",
                  pathname === "/circles"
                    ? "rounded-[9px] bg-accent/10 text-foreground shadow-[0_0_0_1px] shadow-accent"
                    : "rounded-lg text-muted-foreground hover:rounded-[9px] hover:shadow-[0_0_0_1px] hover:shadow-accent hover:text-foreground"
                )}
                aria-current={pathname === "/circles" ? "page" : undefined}
              >
                Circles
              </Link>
            </div>
          )}
          <ThemeToggle />
          <div className="hidden h-5 border border-secondary xl:block" />
          <WalletConnectButton />
        </nav>
      </div>
    </header>
  );
}
