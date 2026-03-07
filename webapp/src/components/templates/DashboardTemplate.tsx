import { ReactNode } from "react";
// import { Card, CardContent } from "@/components/ui/card";

interface DashboardTemplateProps {
  main: ReactNode;
}

export function DashboardTemplate({ main }: DashboardTemplateProps) {
  return (
    <div className="flex items-center justify-center p-4 md:p-6">
      {main}
    </div>
  );
}
