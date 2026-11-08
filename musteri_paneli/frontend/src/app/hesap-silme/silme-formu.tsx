'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useAuth } from '@/kancalar/yetkiKullan';
import { deleteAccount } from '@/lib/api';

export default function HesapSilmeFormu() {
  const { user, loading, logout } = useAuth();
  const [password, setPassword] = useState('');
  const [confirmed, setConfirmed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [deleted, setDeleted] = useState(false);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy || !confirmed) return;
    setBusy(true);
    setError('');
    try {
      await deleteAccount(password);
      setPassword('');
      setDeleted(true);
      logout();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Hesap silinemedi; tekrar deneyin.');
    } finally {
      setBusy(false);
    }
  }

  if (deleted) return <p role="status">Hesabınız silindi ve oturumunuz kapatıldı.</p>;
  if (loading) return <p role="status">Oturum kontrol ediliyor…</p>;
  if (!user) return <p><Link href="/giris?donus=%2Fhesap-silme">Hesabınızı silmek için giriş yapın</Link>.</p>;
  if (!['user', 'customer', 'musteri'].includes(user.role)) {
    return <p>Admin ve personel hesapları için yöneticinizle iletişime geçin.</p>;
  }

  return (
    <form onSubmit={submit} className="not-prose yb-card yb-card-peach yb-delete-form">
      <h2 className="text-xl font-bold">Hesabımı sil</h2>
      <p>{user.email} hesabı için şifrenizi girin.</p>
      <label className="block" htmlFor="silme-sifresi">Şifreniz</label>
      <input id="silme-sifresi" type="password" autoComplete="current-password" required maxLength={128}
        value={password} onChange={event => setPassword(event.target.value)} disabled={busy}
        className="yb-delete-password" />
      <label className="yb-delete-confirm">
        <input type="checkbox" required checked={confirmed} disabled={busy}
          onChange={event => setConfirmed(event.target.checked)} className="mt-1" />
        <span>Hesabımın silineceğini, kalan kredilerimin sıfırlanacağını ve işlemin geri alınamayacağını anladım.</span>
      </label>
      {error && <p role="alert" className="text-tehlike">{error}</p>}
      <button type="submit" disabled={busy || !confirmed || !password}
        className="yb-btn bg-tehlike text-white disabled:opacity-50">
        {busy ? 'Hesabınız siliniyor…' : 'Hesabımı kalıcı olarak sil'}
      </button>
    </form>
  );
}
