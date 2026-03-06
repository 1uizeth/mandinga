import { ReactNode } from "react";

interface DashboardTemplateProps {
  header: ReactNode;
  main: ReactNode;
}

export function DashboardTemplate({ header, main }: DashboardTemplateProps) {
  return (
    <div className="min-h-screen flex flex-col">
      {header}
      <main className="flex-1 container mx-auto px-4 py-6">{main}</main>
    </div>
  );
}
