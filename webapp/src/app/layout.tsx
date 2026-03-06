import "@/lib/polyfills";
import type { Metadata } from "next";
import { GeistPixelLine } from "geist/font/pixel";
import localFont from "next/font/local";
import "./globals.css";
import { Providers } from "./providers";
import { AppHeader } from "@/components/organisms/AppHeader";

const geistMono = localFont({
  src: "./fonts/GeistMonoVF.woff",
  variable: "--font-geist-mono",
  weight: "100 900",
});

export const metadata: Metadata = {
  title: "Mandinga — DeFi Dashboard",
  description: "Savings circles and yield dashboard",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${GeistPixelLine.variable} ${geistMono.variable} font-sans antialiased`}
      >
        <Providers>
          <div className="min-h-screen flex flex-col">
            <AppHeader />
            <main className="flex-1">{children}</main>
          </div>
        </Providers>
      </body>
    </html>
  );
}
