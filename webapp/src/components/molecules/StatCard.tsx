import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export interface StatCardProps {
  label: string;
  value: React.ReactNode;
  subValue?: React.ReactNode;
  className?: string;
}

export function StatCard({ label, value, subValue, className }: StatCardProps) {
  return (
    <Card className={cn("card-dark-gradient", className)}>
      <CardContent className="p-4">
        <p className="text-sm text-muted-foreground">{label}</p>
        <p className="text-xl font-semibold mt-1">{value}</p>
        {subValue && (
          <p className="text-sm text-muted-foreground mt-0.5">{subValue}</p>
        )}
      </CardContent>
    </Card>
  );
}
