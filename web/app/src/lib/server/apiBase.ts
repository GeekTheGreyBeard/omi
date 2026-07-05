const DEFAULT_API_BASE_URL = 'https://omi.splat-i.io';

export function getServerApiBaseUrl(): string {
  return (
    process.env.SERVER_API_BASE_URL ||
    process.env.NEXT_PUBLIC_API_BASE_URL ||
    DEFAULT_API_BASE_URL
  ).replace(/\/+$/, '');
}
