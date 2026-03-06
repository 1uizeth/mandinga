import { ReactNode } from "react";
import { Card, CardContent } from "@/components/ui/card";
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
      <main className="flex-1 flex items-start justify-center p-4 md:p-6">
        <Card className="w-full max-w-4xl">
          <CardContent className="p-6 md:p-8">
            {filters && (
              <div className="mb-6 flex flex-wrap gap-4">{filters}</div>
            )}
            <Grid cols={3}>{cardGrid}</Grid>
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
