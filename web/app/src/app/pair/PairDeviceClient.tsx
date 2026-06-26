'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { setPortalToken } from '@/lib/firebase';

type PairingStatus = 'pending' | 'approved' | 'declined' | 'expired';

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

type PairDeviceMode = 'login' | 'register';

const pairingErrorMessage = (error: unknown, retryAfterSeconds?: number): string => {
  if (error === 'missing_identity') return 'Enter the phone number shown in the Omi app.';
  if (error === 'portal_access_locked') return 'Portal access is locked. Unlock it from the Omi app before logging in.';
  if (error === 'portal_phone_locked') return `Try again in ${retryAfterSeconds ?? 30} seconds.`;
  if (error === 'portal_login_registration_locked') return `Login and registration are locked for ${retryAfterSeconds ?? 300} seconds.`;
  if (error === 'portal_phone_not_registered') return `That phone number is not registered. Try again in ${retryAfterSeconds ?? 30} seconds.`;
  if (typeof error === 'string') return error.replaceAll('_', ' ');
  return 'Could not create a portal login request.';
};

const copy = {
  login: {
    eyebrow: 'Device login',
    title: 'Use your Omi device to unlock the portal.',
    body:
      'Enter the phone number from your Omi app. A short-lived login request will appear on that phone for approval.',
    submit: 'Send login request',
    loading: 'Sending...',
    headerAction: 'Register',
    headerHref: '/register',
  },
  register: {
    eyebrow: 'Device registration',
    title: 'Register this browser with your Omi device.',
    body:
      'Enter the phone number from your Omi app to create a secure registration request. Approve it on that phone to finish.',
    submit: 'Send registration request',
    loading: 'Sending...',
    headerAction: 'Log in',
    headerHref: '/login',
  },
} satisfies Record<PairDeviceMode, Record<string, string>>;

export function PairDeviceClient({ mode = 'login' }: { mode?: PairDeviceMode }) {
  const router = useRouter();
  const pageCopy = copy[mode];
  const [pairing, setPairing] = useState<PortalPairing | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [secondsRemaining, setSecondsRemaining] = useState(0);
  const [phoneNumber, setPhoneNumber] = useState('');
  const [retryAfterRemaining, setRetryAfterRemaining] = useState(0);

  const createPairing = useCallback(async () => {
    const trimmedPhone = phoneNumber.trim();
    if (!trimmedPhone) {
      setError('Enter the phone number shown in the Omi app.');
      setLoading(false);
      return;
    }
    if (retryAfterRemaining > 0) return;

    setLoading(true);
    setError(null);
    try {
      const response = await fetch('/api/portal-pairing', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          phoneNumber: trimmedPhone,
        }),
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        const retryAfterSeconds = Number(data?.retryAfterSeconds ?? data?.retry_after_seconds ?? 0);
        if (retryAfterSeconds > 0) setRetryAfterRemaining(retryAfterSeconds);
        throw new Error(pairingErrorMessage(data?.error, retryAfterSeconds));
      }
      setPairing(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create a portal login request.');
    } finally {
      setLoading(false);
    }
  }, [phoneNumber, retryAfterRemaining]);

  useEffect(() => {
    if (retryAfterRemaining <= 0) return;
    const timer = window.setInterval(() => {
      setRetryAfterRemaining((current) => Math.max(0, current - 1));
    }, 1000);
    return () => window.clearInterval(timer);
  }, [retryAfterRemaining]);

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
          <Link href="/" className="text-lg font-semibold tracking-normal text-text-primary">
            Omi
          </Link>
          <Link
            href={pageCopy.headerHref}
            className="rounded-full border border-white/10 px-4 py-2 text-sm text-text-secondary transition hover:border-white/25 hover:text-white"
          >
            {pageCopy.headerAction}
          </Link>
        </header>

        <section className="grid flex-1 items-center gap-10 py-10 lg:grid-cols-[1fr_420px]">
          <div className="max-w-xl">
            <p className="mb-4 text-sm font-medium uppercase tracking-[0.16em] text-purple-primary">
              {pageCopy.eyebrow}
            </p>
            <h1 className="mb-5 text-4xl font-semibold leading-tight text-white sm:text-5xl">
              {pageCopy.title}
            </h1>
            <p className="text-lg leading-8 text-text-tertiary">{pageCopy.body}</p>
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
                {error && <p className="text-sm text-error">{error}</p>}
                <button
                  type="submit"
                  disabled={loading || retryAfterRemaining > 0}
                  className="w-full rounded-full bg-white px-5 py-3 font-medium text-black transition hover:bg-text-secondary disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {retryAfterRemaining > 0 ? `Try again in ${retryAfterRemaining}s` : loading ? pageCopy.loading : pageCopy.submit}
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
                {mode === 'register' && (
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
                )}

                <div className="rounded-[8px] bg-bg-tertiary p-4">
                  {pairing.status === 'approved' ? (
                    <div>
                      <p className="font-medium text-success">Approved</p>
                      <p className="mt-1 text-sm text-text-tertiary">
                        {pairing.authenticator_device?.display_name || 'Your Omi device'} approved this browser.
                      </p>
                    </div>
                  ) : pairing.status === 'declined' ? (
                    <div>
                      <p className="font-medium text-error">Declined</p>
                      <p className="mt-1 text-sm text-text-tertiary">The Omi app declined this portal login request.</p>
                    </div>
                  ) : expired ? (
                    <div>
                      <p className="font-medium text-warning">Request expired</p>
                      <p className="mt-1 text-sm text-text-tertiary">Send a new request to continue.</p>
                    </div>
                  ) : (
                    <div>
                      <p className="font-medium text-text-secondary">Waiting for device approval</p>
                      <p className="mt-1 text-sm text-text-tertiary">
                        {mode === 'login'
                          ? `Check the Omi app on ${pairing.requested_phone_number || phoneNumber} and allow this portal login.`
                          : `Waiting for ${pairing.requested_phone_number || phoneNumber} to approve this portal request in the Omi app.`}
                        Expires in {secondsRemaining}s.
                      </p>
                    </div>
                  )}
                </div>

                <button
                  onClick={createPairing}
                  className="w-full rounded-full bg-white px-5 py-3 font-medium text-black transition hover:bg-text-secondary disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={pairing.status === 'approved'}
                >
                  {mode === 'login' ? 'Send new login request' : 'Send new registration request'}
                </button>
                <button
                  onClick={() => {
                    setPairing(null);
                    setError(null);
                  }}
                  className="w-full rounded-full border border-white/10 px-5 py-3 font-medium text-text-secondary transition hover:border-white/25 hover:text-white"
                  disabled={pairing.status === 'approved'}
                >
                  Change phone number
                </button>
              </div>
            )}
          </div>
        </section>
      </div>
    </main>
  );
}
