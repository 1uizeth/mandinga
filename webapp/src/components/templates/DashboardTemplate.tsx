import { ReactNode } from "react";
import { Card, CardContent } from "@/components/ui/card";

interface DashboardTemplateProps {
  header: ReactNode;
  main: ReactNode;
}

export function DashboardTemplate({ header, main }: DashboardTemplateProps) {
  return (
    <div className="min-h-screen flex flex-col">
      {header}
      <main className="flex-1 flex items-center justify-center p-4 md:p-6">
        <Card className="w-full max-w-2xl">
          <CardContent className="p-6 md:p-8">{main}</CardContent>
        </Card>
      </main>
    </div>
  );
}
