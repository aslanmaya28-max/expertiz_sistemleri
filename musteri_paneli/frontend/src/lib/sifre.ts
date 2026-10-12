/** Backend kurali ile ayni (auth_service._validate_password_strength). */
export const SIFRE_KURALI = "En az 8 karakter; en az bir büyük harf, bir küçük harf ve bir rakam içermelidir.";

export function sifreHatasi(sifre: string): string | null {
  if (sifre.length < 8) return "Şifre en az 8 karakter olmalıdır";
  if (!/[A-Z]/.test(sifre)) return "Şifre en az bir büyük harf içermelidir";
  if (!/[a-z]/.test(sifre)) return "Şifre en az bir küçük harf içermelidir";
  if (!/[0-9]/.test(sifre)) return "Şifre en az bir rakam içermelidir";
  return null;
}
