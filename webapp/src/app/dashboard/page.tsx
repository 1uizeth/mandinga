import { DashboardTemplate } from "@/components/templates/DashboardTemplate";

export default function DashboardPage() {
  return (
    <DashboardTemplate
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
