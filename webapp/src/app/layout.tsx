import type { Metadata } from "next";
import { GeistPixelLine } from "geist/font/pixel";
import localFont from "next/font/local";
import "./globals.css";
import { Providers } from "./providers";

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
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
