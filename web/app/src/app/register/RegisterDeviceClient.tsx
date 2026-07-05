'use client';

import { useState } from 'react';
import Link from 'next/link';

interface GeneratedAccountCode {
  code: string;
  uid?: string;
  displayName?: string;
  expiresAt?: string;
  expiresInSeconds?: number;
}

const accountCodeErrorMessage = (error: unknown): string => {
  if (error === 'phoneNumber is required') return 'Enter the phone number shown in the Omi app.';
  if (error === 'phoneNumber is too short') return 'Enter the full phone number shown in the Omi app.';
  if (error === 'deviceIdentifier is required') return 'Enter the Android ID shown in the Omi app.';
  if (error === 'device identifier must contain 8 to 64 safe characters') {
    return 'Enter the Android ID exactly as shown in the Omi app.';
  }
  if (typeof error === 'string') return error.replaceAll('_', ' ');
  return 'Could not generate a registration code.';
};

export function RegisterDeviceClient() {
  const [phoneNumber, setPhoneNumber] = useState('');
  const [deviceIdentifier, setDeviceIdentifier] = useState('');
  const [displayName, setDisplayName] = useState('RaBobster');
  const [generatedCode, setGeneratedCode] = useState<GeneratedAccountCode | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const generateCode = async () => {
    const trimmedPhone = phoneNumber.trim();
    const trimmedDeviceIdentifier = deviceIdentifier.trim();
    if (!trimmedPhone) {
      setError('Enter the phone number shown in the Omi app.');
      return;
    }
    if (!trimmedDeviceIdentifier) {
      setError('Enter the Android ID shown in the Omi app.');
      return;
    }

    setLoading(true);
    setError(null);
    setGeneratedCode(null);
    try {
      const response = await fetch('/api/account-codes/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          phoneNumber: trimmedPhone,
          deviceIdentifier: trimmedDeviceIdentifier,
          displayName: displayName.trim(),
        }),
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(accountCodeErrorMessage(data?.detail ?? data?.error));
      }
      setGeneratedCode(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not generate a registration code.');
    } finally {
      setLoading(false);
    }
  };

  const expiresAtLabel = generatedCode?.expiresAt
    ? new Date(generatedCode.expiresAt).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
    : null;

  return (
    <main className="min-h-screen bg-bg-primary text-text-primary">
      <div className="mx-auto flex min-h-screen w-full max-w-5xl flex-col px-5 py-6 sm:px-8">
        <header className="flex items-center justify-between">
          <Link href="/" className="text-lg font-semibold tracking-normal text-text-primary">
            Omi
          </Link>
          <Link
            href="/login"
            className="rounded-full border border-white/10 px-4 py-2 text-sm text-text-secondary transition hover:border-white/25 hover:text-white"
          >
            Log in
          </Link>
        </header>

        <section className="grid flex-1 items-center gap-10 py-10 lg:grid-cols-[1fr_420px]">
          <div className="max-w-xl">
            <p className="mb-4 text-sm font-medium uppercase tracking-[0.16em] text-purple-primary">
              Device registration
            </p>
            <h1 className="mb-5 text-4xl font-semibold leading-tight text-white sm:text-5xl">
              Generate an Omi app registration code.
            </h1>
            <p className="text-lg leading-8 text-text-tertiary">
              Enter the phone number and Android ID shown in the Omi app. Use the generated code on that device to
              complete registration.
            </p>
          </div>

          <div className="rounded-[8px] border border-white/10 bg-bg-secondary p-6 shadow-2xl shadow-black/30">
            {!generatedCode && (
              <form
                className="space-y-4"
                onSubmit={(event) => {
                  event.preventDefault();
                  generateCode();
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
                    autoComplete="tel"
                    className="w-full rounded-[8px] border border-white/10 bg-black px-4 py-3 text-white outline-none transition placeholder:text-text-tertiary focus:border-purple-primary"
                  />
                </div>
                <div>
                  <label className="mb-2 block text-sm text-text-tertiary" htmlFor="deviceIdentifier">
                    Android ID
                  </label>
                  <input
                    id="deviceIdentifier"
                    value={deviceIdentifier}
                    onChange={(event) => setDeviceIdentifier(event.target.value)}
                    placeholder="Android ID from the Omi app"
                    autoComplete="off"
                    autoCapitalize="none"
                    spellCheck={false}
                    className="w-full rounded-[8px] border border-white/10 bg-black px-4 py-3 font-mono text-white outline-none transition placeholder:font-sans placeholder:text-text-tertiary focus:border-purple-primary"
                  />
                </div>
                <div>
                  <label className="mb-2 block text-sm text-text-tertiary" htmlFor="displayName">
                    Device name
                  </label>
                  <input
                    id="displayName"
                    value={displayName}
                    onChange={(event) => setDisplayName(event.target.value)}
                    placeholder="RaBobster"
                    autoComplete="off"
                    className="w-full rounded-[8px] border border-white/10 bg-black px-4 py-3 text-white outline-none transition placeholder:text-text-tertiary focus:border-purple-primary"
                  />
                </div>
                {error && <p className="text-sm text-error">{error}</p>}
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full rounded-full bg-white px-5 py-3 font-medium text-black transition hover:bg-text-secondary disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {loading ? 'Generating...' : 'Generate registration code'}
                </button>
              </form>
            )}

            {generatedCode && (
              <div className="space-y-6">
                <div>
                  <p className="mb-2 text-sm text-text-tertiary">Registration code</p>
                  <div className="rounded-[8px] border border-white/10 bg-black px-4 py-5 text-center font-mono text-5xl font-semibold tracking-[0.18em] text-white">
                    {generatedCode.code}
                  </div>
                </div>
                <div className="rounded-[8px] bg-bg-tertiary p-4">
                  <p className="font-medium text-success">Code ready</p>
                  <p className="mt-1 text-sm leading-6 text-text-tertiary">
                    Enter this code in the Omi app on {phoneNumber.trim()}.{' '}
                    {expiresAtLabel ? `It expires at ${expiresAtLabel}.` : 'It expires shortly.'}
                  </p>
                </div>
                <button
                  onClick={() => {
                    setGeneratedCode(null);
                    setError(null);
                  }}
                  className="w-full rounded-full bg-white px-5 py-3 font-medium text-black transition hover:bg-text-secondary"
                >
                  Generate another code
                </button>
                <button
                  onClick={() => {
                    setPhoneNumber('');
                    setDeviceIdentifier('');
                    setGeneratedCode(null);
                    setError(null);
                  }}
                  className="w-full rounded-full border border-white/10 px-5 py-3 font-medium text-text-secondary transition hover:border-white/25 hover:text-white"
                >
                  Clear form
                </button>
              </div>
            )}
          </div>
        </section>
      </div>
    </main>
  );
}
