import { NextRequest, NextResponse } from 'next/server';

const API_BASE_URL = process.env.SERVER_API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || 'https://omi.splat-i.io';

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const response = await fetch(`${API_BASE_URL}/v1/portal-pairing/${encodeURIComponent(id)}`, {
      cache: 'no-store',
    });

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    console.error('Portal pairing status error:', error);
    return NextResponse.json({ error: 'pairing_status_failed' }, { status: 500 });
  }
}
