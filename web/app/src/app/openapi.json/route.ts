import { NextResponse } from 'next/server';
import { getServerApiBaseUrl } from '@/lib/server/apiBase';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const response = await fetch(`${getServerApiBaseUrl()}/openapi.json`, {
      headers: { accept: 'application/json' },
      cache: 'no-store',
    });
    const body = await response.text();
    return new NextResponse(body, {
      status: response.status,
      headers: {
        'content-type': response.headers.get('content-type') || 'application/json; charset=utf-8',
        'cache-control': 'no-store',
      },
    });
  } catch {
    return NextResponse.json({ error: 'openapi_proxy_failed' }, { status: 502 });
  }
}
