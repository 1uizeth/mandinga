import * as React from "react";
import { cn } from "@/lib/utils";

interface GridProps extends React.HTMLAttributes<HTMLDivElement> {
  cols?: 1 | 2 | 3 | "auto";
}

const Grid = React.forwardRef<HTMLDivElement, GridProps>(
  ({ className, cols = 3, ...props }, ref) => {
    const colsClass =
      cols === 1
        ? "grid-cols-1"
        : cols === 2
          ? "grid-cols-1 md:grid-cols-2"
          : cols === 3
            ? "grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
            : "grid-cols-1 md:grid-cols-2 lg:grid-cols-3";
    return (
      <div
        ref={ref}
        className={cn("grid gap-4", colsClass, className)}
        {...props}
      />
    );
  }
);
Grid.displayName = "Grid";

export { Grid };
