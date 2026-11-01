"use client";

import { useParams } from "next/navigation";
import RaporDogrulama from "@/bilesenler/RaporDogrulama";

export default function KodDogrulamaSayfasi() {
  const { kod } = useParams<{ kod: string }>();
  return <RaporDogrulama key={kod} initialCode={kod} />;
}
