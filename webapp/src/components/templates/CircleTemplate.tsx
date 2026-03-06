import { ReactNode } from "react";
import { Grid } from "@/components/ui/grid";

interface CircleTemplateProps {
  header: ReactNode;
  filters?: ReactNode;
  cardGrid: ReactNode;
}

export function CircleTemplate({
  header,
  filters,
  cardGrid,
}: CircleTemplateProps) {
  return (
    <div className="min-h-screen flex flex-col">
      {header}
      <main className="flex-1 container mx-auto px-4 py-6">
        {filters && (
          <div className="mb-6 flex flex-wrap gap-4">{filters}</div>
        )}
        <Grid cols={3}>{cardGrid}</Grid>
      </main>
    </div>
  );
}
