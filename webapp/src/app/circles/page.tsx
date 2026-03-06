import { CircleTemplate } from "@/components/templates/CircleTemplate";

export default function CirclesPage() {
  return (
    <CircleTemplate
      cardGrid={
        <p className="text-muted-foreground col-span-full">
          Connect your wallet to view your circles.
        </p>
      }
    />
  );
}
