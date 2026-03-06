import { AppHeader } from "@/components/organisms/AppHeader";
import { DashboardTemplate } from "@/components/templates/DashboardTemplate";
import Link from "next/link";

export default function Home() {
  return (
    <DashboardTemplate
      header={<AppHeader />}
      main={
        <div className="flex flex-col items-center justify-center py-16 gap-6">
          <h1 className="text-3xl font-bold">Mandinga</h1>
          <p className="text-muted-foreground text-center max-w-md">
            DeFi Dashboard — connect your wallet to access savings, circles, and
            yield.
          </p>
          <Link
            href="/dashboard"
            className="rounded-md bg-primary px-4 py-2 text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            Go to Dashboard
          </Link>
        </div>
      }
    />
  );
}
