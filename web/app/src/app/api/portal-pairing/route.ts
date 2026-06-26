import { NextRequest, NextResponse } from 'next/server';

const API_BASE_URL = process.env.SERVER_API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || 'https://omi.splat-i.io';

export async function POST(request: NextRequest) {
  try {
    const requestBody = await request.json().catch(() => ({}));
    const response = await fetch(`${API_BASE_URL}/v1/portal-pairing`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        user_agent: request.headers.get('user-agent') || '',
        phoneNumber: requestBody.phoneNumber || requestBody.phone_number || '',
        phone_number: requestBody.phoneNumber || requestBody.phone_number || '',
      }),
    });

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    console.error('Portal pairing create error:', error);
    return NextResponse.json({ error: 'pairing_create_failed' }, { status: 500 });
  }
}
