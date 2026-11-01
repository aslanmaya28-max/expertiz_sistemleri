import type { Metadata } from "next";
import RaporDogrulama from "@/bilesenler/RaporDogrulama";

export const metadata: Metadata = { title: "Rapor doğrula" };

export default function DogrulaSayfasi() {
  return <RaporDogrulama />;
}
