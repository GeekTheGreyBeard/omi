type PortalUser = {
  uid: string;
  displayName: string | null;
  email: string | null;
  photoURL: string | null;
};

export type MessagePayload = {
  data?: Record<string, string>;
  notification?: {
    title?: string;
    body?: string;
  };
};

const PORTAL_TOKEN_KEY = 'splatiPortalToken';
export const PORTAL_TOKEN_CHANGED_EVENT = 'portal-token-changed';

const notifyPortalTokenChanged = (): void => {
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new Event(PORTAL_TOKEN_CHANGED_EVENT));
  }
};

const decodeJwtPayload = (token: string): Record<string, unknown> | null => {
  try {
    const payload = token.split('.')[1];
    if (!payload) return null;
    const normalized = payload.replace(/-/g, '+').replace(/_/g, '/');
    const padded = normalized.padEnd(normalized.length + ((4 - normalized.length % 4) % 4), '=');
    return JSON.parse(window.atob(padded)) as Record<string, unknown>;
  } catch {
    return null;
  }
};

export const getPortalToken = (): string | null => {
  if (typeof window === 'undefined') return null;
  return window.localStorage.getItem(PORTAL_TOKEN_KEY);
};

export const getPortalUid = (): string | null => {
  const token = getPortalToken();
  if (!token) return null;

  const payload = decodeJwtPayload(token);
  const uid = payload?.uid || payload?.sub;
  return typeof uid === 'string' && uid.length > 0 ? uid : null;
};

export const setPortalToken = (token: string): void => {
  window.localStorage.setItem(PORTAL_TOKEN_KEY, token);
  notifyPortalTokenChanged();
};

export const clearPortalToken = (): void => {
  if (typeof window !== 'undefined') {
    window.localStorage.removeItem(PORTAL_TOKEN_KEY);
    notifyPortalTokenChanged();
  }
};

export const getPortalUser = (): PortalUser | null => {
  return getPortalToken()
    ? {
        uid: getPortalUid() || 'portal-device',
        displayName: 'Paired Omi device',
        email: null,
        photoURL: null,
      }
    : null;
};

export const signOutUser = async (): Promise<void> => {
  clearPortalToken();
};

export const getPlatformToken = async (): Promise<string | null> => {
  return getPortalToken();
};

export const onAuthStateChange = (callback: (user: PortalUser | null) => void) => {
  callback(getPortalUser());
  return () => {};
};

export const requestNotificationPermission = async (): Promise<string | null> => null;

export const getCurrentFCMToken = async (): Promise<string | null> => null;

export const onForegroundMessage = async (
  _callback: (payload: MessagePayload) => void
): Promise<(() => void) | null> => null;

export const getNotificationPermission = (): NotificationPermission | 'unsupported' => {
  if (typeof window === 'undefined' || !('Notification' in window)) {
    return 'unsupported';
  }
  return Notification.permission;
};
