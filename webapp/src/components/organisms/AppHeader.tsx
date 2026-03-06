import Link from "next/link";
import { WalletConnectButton } from "@/components/molecules/WalletConnectButton";
import { ThemeToggle } from "@/components/molecules/ThemeToggle";

export function AppHeader() {
  return (
    <header className="sticky top-0 z-50 w-full border-b border-border bg-background">
      <div className="flex h-16 md:h-20 w-full items-center justify-between px-4 md:px-6 lg:px-8">
        <Link
          href="/"
          className="text-2xl md:text-3xl font-medium tracking-tight text-foreground hover:opacity-80 transition-opacity"
        >
          Mandinga
        </Link>
        <div className="flex items-center gap-2">
          <ThemeToggle />
          <WalletConnectButton />
        </div>
      </div>
    </header>
  );
}
