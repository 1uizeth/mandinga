"use client";

import { useState } from "react";
import { DashboardTemplate } from "@/components/templates/DashboardTemplate";
import { SavingsPositionCard } from "@/components/organisms/SavingsPositionCard";
import { JoinCircleCard } from "@/components/organisms/JoinCircleCard";
import { JoinCircleModal } from "@/components/organisms/JoinCircleModal";
import { useSavingsPosition } from "@/hooks/useSavingsPosition";

export default function DashboardPage() {
  const { position } = useSavingsPosition();
  const [circleModalOpen, setCircleModalOpen] = useState(false);
  const [depositModalOpen, setDepositModalOpen] = useState(false);

  const balanceUsdc = position ? Number(position.balance) / 1_000_000 : 0;
  const hasBalance = balanceUsdc > 0;

  return (
    <>
      <DashboardTemplate
        main={
          <SavingsPositionCard
            externalDepositOpen={depositModalOpen}
            onExternalDepositClose={() => setDepositModalOpen(false)}
          />
        }
        below={hasBalance ? <JoinCircleCard onClick={() => setCircleModalOpen(true)} /> : undefined}
      />

      <JoinCircleModal
        open={circleModalOpen}
        onClose={() => setCircleModalOpen(false)}
        balanceUsdc={balanceUsdc}
        onDepositMore={() => setDepositModalOpen(true)}
      />
    </>
  );
}
