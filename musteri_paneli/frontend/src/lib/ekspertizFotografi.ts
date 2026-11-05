import type { InspectionPhotoResult, PrefillField } from "./api";

export function raporFotografiHatasi(files: Pick<File, "size" | "name" | "type">[]): string | null {
  if (files.length < 1 || files.length > 4) return "Bir rapor için 1–4 fotoğraf seçin.";
  if (files.some((file) => !file.size || file.size > 8 * 1024 * 1024)) return "Her fotoğraf boş olmamalı ve en fazla 8 MB olmalıdır.";
  if (files.some((file) => !/\.(jpe?g|png|heic|heif)$/i.test(file.name))) return "JPEG, PNG veya HEIC fotoğraf seçin.";
  return null;
}

export function fotoOnDolum(result: InspectionPhotoResult, partKeys: string[]) {
  const origins: Record<string, PrefillField> = {};
  for (const [key, value] of Object.entries(result.parts)) {
    origins[`parts.${key}`] = { deger: value, kaynak: "ekspertiz_raporu", dogrulandi: false };
  }
  if (result.tramer_amount != null) origins.tramer_amount = {
    deger: result.tramer_amount, kaynak: "ekspertiz_raporu", dogrulandi: false,
  };
  return { parts: { ...result.parts }, tramer: result.tramer_amount == null ? "" : String(result.tramer_amount),
    origins, belirsiz: partKeys.filter((key) => !(key in result.parts)) };
}
