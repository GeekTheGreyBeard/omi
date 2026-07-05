import { NextRequest, NextResponse } from 'next/server';

const ACCOUNT_CODE_API_BASE_URL =
  process.env.SPLATI_AUTH_BASE_URL ||
  process.env.OMI_AUTH_BASE_URL ||
  process.env.SERVER_API_BASE_URL ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  'http://omi-auth-staging.gtgb.io';

export async function POST(request: NextRequest) {
  try {
    const requestBody = await request.json().catch(() => ({}));
    const adminToken = process.env.OMI_AUTH_ADMIN_TOKEN || process.env.SPLATI_AUTH_ADMIN_TOKEN || '';
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (adminToken) headers['X-Omi-Auth-Admin-Token'] = adminToken;

    const deviceIdentifier = requestBody.deviceIdentifier || requestBody.device_identifier || requestBody.imei || '';
    const phoneNumber = requestBody.phoneNumber || requestBody.phone_number || '';
    const response = await fetch(`${ACCOUNT_CODE_API_BASE_URL}/api/account-codes/generate/`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        phoneNumber,
        phone_number: phoneNumber,
        deviceIdentifier,
        imei: deviceIdentifier,
        displayName: requestBody.displayName || requestBody.display_name || '',
      }),
    });

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    console.error('Account code generate error:', error);
    return NextResponse.json({ error: 'account_code_generate_failed' }, { status: 500 });
  }
}
