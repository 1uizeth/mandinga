import { AppHeader } from "@/components/organisms/AppHeader";
import { DashboardTemplate } from "@/components/templates/DashboardTemplate";

export default function DashboardPage() {
  return (
    <DashboardTemplate
      header={<AppHeader />}
      main={
        <div className="space-y-6">
          <h2 className="text-2xl font-semibold">Dashboard</h2>
          <p className="text-muted-foreground">
            Connect your wallet to view your savings account and yield.
          </p>
        </div>
      }
    />
  );
}
