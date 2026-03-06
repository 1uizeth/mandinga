import Link from "next/link";

export function AppHeader() {
  return (
    <header className="surfaceTopbar sticky top-0 z-50 w-full">
      <div className="container flex h-14 items-center">
        <Link href="/" className="flex items-center space-x-2 font-semibold">
          Mandinga
        </Link>
        <nav className="ml-6 flex gap-6">
          <Link
            href="/dashboard"
            className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
          >
            Dashboard
          </Link>
          <Link
            href="/circles"
            className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
          >
            Circles
          </Link>
        </nav>
      </div>
    </header>
  );
}
