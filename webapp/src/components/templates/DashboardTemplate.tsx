import { ReactNode } from "react";

interface DashboardTemplateProps {
  main: ReactNode;
  below?: ReactNode;
}

export function DashboardTemplate({ main, below }: DashboardTemplateProps) {
  return (
    <div className="flex justify-center p-4 md:p-6 pt-10 md:pt-16">
      <div className="w-full max-w-md flex flex-col gap-4">
        {main}
        {below}
      </div>
    </div>
  );
}
