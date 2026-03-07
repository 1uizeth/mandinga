"use client";

import { useAccount } from "wagmi";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

export default function Home() {
  const { isConnected } = useAccount();

  return (
    <div className="flex items-start justify-center p-4 md:p-6">
      <div className="w-full max-w-4xl space-y-8">
        <div className="flex flex-col items-center justify-center py-8 gap-6">
          {isConnected ? (
            <>
              <h1 className="text-2xl font-semibold">Welcome to Mandinga</h1>
              <p className="text-muted-foreground text-center max-w-md">
                DeFi Dashboard — access your savings, circles, and yield.
              </p>
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

        <section>
          <h2 className="text-xl font-semibold mb-4">Browse available circles</h2>
          <Card>
            <CardContent className="p-6">
              <p className="text-muted-foreground mb-4">
                Discover and join savings circles. Connect your wallet to view
                circles you participate in or browse available circles to join.
              </p>
              <Link href="/circles">
                <Button variant="outline">View Circles</Button>
              </Link>
            </CardContent>
          </Card>
        </section>
      </div>
    </div>
  );
}
