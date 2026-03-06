"use client";

import "@rainbow-me/rainbowkit/styles.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  RainbowKitProvider,
  lightTheme,
  darkTheme,
} from "@rainbow-me/rainbowkit";
import { WagmiProvider } from "wagmi";
import { ThemeProvider, useTheme } from "next-themes";
import { config } from "@/lib/wagmi";
import { useState } from "react";

const rainbowLightTheme = lightTheme({
  accentColor: "hsl(0, 0%, 9%)",
  accentColorForeground: "hsl(0, 0%, 98%)",
  borderRadius: "medium",
  fontStack: "system",
});

const rainbowDarkTheme = darkTheme({
  accentColor: "hsl(0, 0%, 98%)",
  accentColorForeground: "hsl(0, 0%, 9%)",
  borderRadius: "medium",
  fontStack: "system",
});

function RainbowKitThemeWrapper({ children }: { children: React.ReactNode }) {
  const { resolvedTheme } = useTheme();
  const theme =
    resolvedTheme === "dark" ? rainbowDarkTheme : rainbowLightTheme;

  return <RainbowKitProvider theme={theme}>{children}</RainbowKitProvider>;
}

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
      <WagmiProvider config={config}>
        <QueryClientProvider client={queryClient}>
          <RainbowKitThemeWrapper>{children}</RainbowKitThemeWrapper>
        </QueryClientProvider>
      </WagmiProvider>
    </ThemeProvider>
  );
}
