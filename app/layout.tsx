import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "CT Workspace",
    template: "%s | CT Workspace",
  },
  description: "Gestão interna de projetos da CT Ítalo Vieira e Netmitt.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
