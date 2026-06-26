'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { setPortalToken } from '@/lib/firebase';

type PairingStatus = 'pending' | 'approved' | 'expired';

interface PortalPairing {
  id: string;
  code: string;
  status: PairingStatus;
  expires_at: string;
  requested_phone_number?: string;
  requested_device_identifier?: string;
  portalToken?: string;
  portal_token?: string;
  authenticator_device?: {
    display_name?: string;
    device_identifier?: string;
  } | null;
}

export function PairDeviceClient() {
  const router = useRouter();
  const [pairing, setPairing] = useState<PortalPairing | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [secondsRemaining, setSecondsRemaining] = useState(0);
  const [phoneNumber, setPhoneNumber] = useState('');
  const [deviceIdentifier, setDeviceIdentifier] = useState('');
  const [deviceIdentifierType, setDeviceIdentifierType] = useState('device');

  const createPairing = useCallback(async () => {
    const trimmedPhone = phoneNumber.trim();
    const trimmedDevice = deviceIdentifier.trim();
    if (!trimmedPhone || !trimmedDevice) {
      setError('Enter the phone number and device ID shown in the Omi app.');
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const response = await fetch('/api/portal-pairing', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          phoneNumber: trimmedPhone,
          deviceIdentifier: trimmedDevice,
          deviceIdentifierType,
        }),
      });
      if (!response.ok) throw new Error('Could not create a pairing code.');
      setPairing(await response.json());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create a pairing code.');
    } finally {
      setLoading(false);
    }
  }, [deviceIdentifier, deviceIdentifierType, phoneNumber]);

  useEffect(() => {
    if (!pairing || pairing.status !== 'pending') return;

    const updateTimer = () => {
      setSecondsRemaining(Math.max(0, Math.floor((new Date(pairing.expires_at).getTime() - Date.now()) / 1000)));
    };

    updateTimer();
    const timer = window.setInterval(updateTimer, 1000);
    return () => window.clearInterval(timer);
  }, [pairing]);

  useEffect(() => {
    if (!pairing || pairing.status !== 'pending') return;

    const poller = window.setInterval(async () => {
      try {
        const response = await fetch(`/api/portal-pairing/${encodeURIComponent(pairing.id)}`, { cache: 'no-store' });
        if (!response.ok) return;
        const nextPairing = await response.json();
        setPairing(nextPairing);
        const token = nextPairing.portalToken || nextPairing.portal_token;
        if (nextPairing.status === 'approved' && token) {
          setPortalToken(token);
          window.setTimeout(() => router.push('/conversations'), 900);
        }
      } catch (err) {
        console.error('Portal pairing poll failed:', err);
      }
    }, 2000);

    return () => window.clearInterval(poller);
  }, [pairing, router]);

  const codeParts = useMemo(() => pairing?.code.split('-') ?? ['', ''], [pairing]);
  const expired = pairing?.status === 'expired' || secondsRemaining === 0;

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <div className="mx-auto flex min-h-screen w-full max-w-5xl flex-col px-5 py-6 sm:px-8">
        <header className="flex items-center justify-between">
          <a href="/login" className="text-lg font-semibold tracking-normal text-text-primary">
            Omi
          </a>
          <a
            href="/login"
            className="rounded-full border border-white/10 px-4 py-2 text-sm text-text-secondary transition hover:border-white/25 hover:text-white"
          >
            Log in
          </a>
        </header>

        <section className="grid flex-1 items-center gap-10 py-10 lg:grid-cols-[1fr_420px]">
          <div className="max-w-xl">
            <p className="mb-4 text-sm font-medium uppercase tracking-[0.16em] text-purple-primary">Device login</p>
            <h1 className="mb-5 text-4xl font-semibold leading-tight text-white sm:text-5xl">
              Use your Omi device to unlock the portal.
            </h1>
            <p className="text-lg leading-8 text-text-tertiary">
              Open Omi on your phone, choose Link web portal, and copy the phone and device identity shown there. This
              code can only be approved by that same phone.
            </p>
          </div>

          <div className="rounded-[8px] border border-white/10 bg-bg-secondary p-6 shadow-2xl shadow-black/30">
            {!pairing && (
              <form
                className="space-y-4"
                onSubmit={(event) => {
                  event.preventDefault();
                  createPairing();
                }}
              >
                <div>
                  <label className="mb-2 block text-sm text-text-tertiary" htmlFor="phoneNumber">
                    Phone number
                  </label>
                  <input
                    id="phoneNumber"
                    value={phoneNumber}
                    onChange={(event) => setPhoneNumber(event.target.value)}
                    placeholder="+15555550100"
                    className="w-full rounded-[8px] border border-white/10 bg-black px-4 py-3 text-white outline-none transition placeholder:text-text-tertiary focus:border-purple-primary"
                  />
                </div>
                <div>
                  <label className="mb-2 block text-sm text-text-tertiary" htmlFor="deviceIdentifier">
                    Device ID
                  </label>
                  <input
                    id="deviceIdentifier"
                    value={deviceIdentifier}
                    onChange={(event) => setDeviceIdentifier(event.target.value)}
                    placeholder="Device identifier from Omi"
                    className="w-full rounded-[8px] border border-white/10 bg-black px-4 py-3 text-white outline-none transition placeholder:text-text-tertiary focus:border-purple-primary"
                  />
                </div>
                <div>
                  <label className="mb-2 block text-sm text-text-tertiary" htmlFor="deviceIdentifierType">
                    Device ID type
                  </label>
                  <select
                    id="deviceIdentifierType"
                    value={deviceIdentifierType}
                    onChange={(event) => setDeviceIdentifierType(event.target.value)}
                    className="w-full rounded-[8px] border border-white/10 bg-black px-4 py-3 text-white outline-none transition focus:border-purple-primary"
                  >
                    <option value="device">Device</option>
                    <option value="android_id">Android ID</option>
                    <option value="imei">IMEI</option>
                  </select>
                </div>
                {error && <p className="text-sm text-error">{error}</p>}
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full rounded-full bg-white px-5 py-3 font-medium text-black transition hover:bg-text-secondary disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {loading ? 'Generating...' : 'Generate pairing code'}
                </button>
              </form>
            )}

            {loading && pairing && (
              <div className="flex h-72 items-center justify-center">
                <div className="h-12 w-12 rounded-full border-4 border-purple-primary/25 border-t-purple-primary animate-spin" />
              </div>
            )}

            {!loading && error && pairing && (
              <div className="space-y-5">
                <p className="text-error">{error}</p>
                <button
                  onClick={createPairing}
                  className="w-full rounded-full bg-white px-5 py-3 font-medium text-black transition hover:bg-text-secondary"
                >
                  Try again
                </button>
              </div>
            )}

            {!loading && pairing && (
              <div className="space-y-6">
                <div>
                  <p className="mb-2 text-sm text-text-tertiary">Pairing code</p>
                  <div className="grid grid-cols-2 gap-3">
                    {codeParts.map((part, index) => (
                      <div
                        key={`${part}-${index}`}
                        className="rounded-[8px] border border-white/10 bg-black px-4 py-5 text-center font-mono text-4xl font-semibold tracking-[0.18em] text-white"
                      >
                        {part}
                      </div>
                    ))}
                  </div>
                </div>

                <div className="rounded-[8px] bg-bg-tertiary p-4">
                  {pairing.status === 'approved' ? (
                    <div>
                      <p className="font-medium text-success">Approved</p>
                      <p className="mt-1 text-sm text-text-tertiary">
                        {pairing.authenticator_device?.display_name || 'Your Omi device'} approved this browser.
                      </p>
                    </div>
                  ) : expired ? (
                    <div>
                      <p className="font-medium text-warning">Code expired</p>
                      <p className="mt-1 text-sm text-text-tertiary">Generate a new code to continue.</p>
                    </div>
                  ) : (
                    <div>
                      <p className="font-medium text-text-secondary">Waiting for device approval</p>
                      <p className="mt-1 text-sm text-text-tertiary">
                        Waiting for {pairing.requested_phone_number || phoneNumber} on{' '}
                        {pairing.requested_device_identifier || deviceIdentifier}. Expires in {secondsRemaining}s.
                      </p>
                    </div>
                  )}
                </div>

                <button
                  onClick={createPairing}
                  className="w-full rounded-full bg-white px-5 py-3 font-medium text-black transition hover:bg-text-secondary disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={pairing.status === 'approved'}
                >
                  Generate new code
                </button>
                <button
                  onClick={() => {
                    setPairing(null);
                    setError(null);
                  }}
                  className="w-full rounded-full border border-white/10 px-5 py-3 font-medium text-text-secondary transition hover:border-white/25 hover:text-white"
                  disabled={pairing.status === 'approved'}
                >
                  Change device identity
                </button>
              </div>
            )}
          </div>
        </section>
      </div>
    </main>
  );
}
