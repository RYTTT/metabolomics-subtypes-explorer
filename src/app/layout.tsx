import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Metabolomics Subtypes Explorer | PTSD, MDD & Cognitive Disorders",
  description: "Cross-comparison, search, annotations, and psychiatric literature references for differentially expressed metabolites across PTSD, MDD, and Cognitive subtypes.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
