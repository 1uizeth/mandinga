import { ReactNode } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Grid } from "@/components/ui/grid";

interface CircleTemplateProps {
  filters?: ReactNode;
  cardGrid: ReactNode;
}

export function CircleTemplate({ filters, cardGrid }: CircleTemplateProps) {
  return (
    <div className="flex items-start justify-center p-4 md:p-6">
      <Card className="w-full max-w-4xl border-none shadow-none bg-transparent">
        <CardContent className="p-6 md:p-8">
          {filters && (
            <div className="mb-6 flex flex-wrap gap-4">{filters}</div>
          )}
          <Grid cols={3}>{cardGrid}</Grid>
        </CardContent>
      </Card>
    </div>
  );
}
