import Link from "next/link";

export function AppHeader() {
  return (
    <header className="surfaceTopbar sticky top-0 z-50 w-full">
      <div className="flex h-16 md:h-20 w-full items-center px-4 md:px-6 lg:px-8">
        <Link
          href="/"
          className="text-2xl md:text-3xl font-medium tracking-tight text-foreground hover:opacity-80 transition-opacity"
        >
          Mandinga
        </Link>
      </div>
    </header>
  );
}
