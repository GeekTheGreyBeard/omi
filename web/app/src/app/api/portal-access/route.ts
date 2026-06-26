import { NextRequest, NextResponse } from 'next/server';

const API_BASE_URL = process.env.SERVER_API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || 'https://omi.splat-i.io';

export async function GET(request: NextRequest) {
  try {
    const phoneNumber = request.nextUrl.searchParams.get('phoneNumber') || request.nextUrl.searchParams.get('phone_number') || '';
    const response = await fetch(
      `${API_BASE_URL}/v1/portal-access?phoneNumber=${encodeURIComponent(phoneNumber)}`,
      { cache: 'no-store' }
    );
    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    console.error('Portal access status error:', error);
    return NextResponse.json({ error: 'portal_access_status_failed' }, { status: 500 });
  }
}
