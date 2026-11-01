export function normalizeVerificationCode(value: string): string {
  return value.trim().toUpperCase();
}

export function isVerificationCode(value: string): boolean {
  return /^YB-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(value);
}
