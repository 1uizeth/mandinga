"use client";

import { DashboardTemplate } from "@/components/templates/DashboardTemplate";
import { useAccount } from "wagmi";
import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function Home() {
  const { isConnected } = useAccount();

  return (
    <DashboardTemplate
      main={
        <div className="flex flex-col items-center justify-center py-12 gap-6">
          {isConnected ? (
            <>
              <h1 className="text-2xl font-semibold">Welcome to Mandinga</h1>
              <p className="text-muted-foreground text-center max-w-md">
                DeFi Dashboard — access your savings, circles, and yield.
              </p>
              <Link href="/dashboard">
                <Button>Go to Dashboard</Button>
              </Link>
            </>
          ) : (
            <>
              <h1 className="text-2xl font-semibold">Connect your wallet</h1>
              <p className="text-muted-foreground text-center max-w-md">
                Connect your wallet to access savings, circles, and yield. Use
                the Connect button in the header.
              </p>
            </>
          )}
        </div>
      }
    />
  );
}
