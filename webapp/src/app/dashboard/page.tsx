import { DashboardTemplate } from "@/components/templates/DashboardTemplate";
import { SavingsPositionCard } from "@/components/organisms/SavingsPositionCard";
import { YieldOverview } from "@/components/organisms/YieldOverview";

export default function DashboardPage() {
  return (
    <DashboardTemplate
      main={
        <div className="space-y-6">
          <YieldOverview />
          <SavingsPositionCard />
        </div>
      }
    />
  );
}
