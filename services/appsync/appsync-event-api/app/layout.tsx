import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AppSync Events API Demo",
  description: "Real-time pub/sub with AWS AppSync Events API",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-gray-950 text-gray-100 antialiased">{children}</body>
    </html>
  );
}
