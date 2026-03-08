import { Users } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

export function JoinCircleCard({ onClick }: { onClick: () => void }) {
  return (
    <Card className="w-full border-dashed">
      <CardContent className="p-6 flex flex-col items-center text-center gap-4">
        <div className="flex h-11 w-11 items-center justify-center rounded-full bg-primary/10">
          <Users className="h-5 w-5 text-primary" />
        </div>
        <div className="flex flex-col gap-1">
          <p className="text-sm font-semibold text-foreground">Join a Savings Circle</p>
          <p className="text-xs text-muted-foreground leading-relaxed">
            Pool savings with others. Each round, one member receives the full pot.
            No interest, no banks — just community.
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={onClick}>
          Browse circles
        </Button>
      </CardContent>
    </Card>
  );
}
