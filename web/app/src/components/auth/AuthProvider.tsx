'use client';

import { createContext, useContext, useEffect, useState, ReactNode, useRef, useCallback } from 'react';
import { User } from 'firebase/auth';
import {
  onAuthStateChange,
  signOutUser,
  getIdToken,
  getPortalToken,
} from '@/lib/firebase';
import { MixpanelManager } from '@/lib/analytics/mixpanel';

type PortalUser = {
  uid: string;
  displayName: string | null;
  email: string | null;
  photoURL: string | null;
};

type AuthUser = User | PortalUser;

interface AuthContextType {
  user: AuthUser | null;
  loading: boolean;
  signOut: () => Promise<void>;
  getToken: () => Promise<string | null>;
  // Login panel state
  isLoginPanelOpen: boolean;
  openLoginPanel: () => void;
  closeLoginPanel: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [isLoginPanelOpen, setIsLoginPanelOpen] = useState(false);
  const previousUserRef = useRef<AuthUser | null>(null);

  const openLoginPanel = useCallback(() => setIsLoginPanelOpen(true), []);
  const closeLoginPanel = useCallback(() => setIsLoginPanelOpen(false), []);

  useEffect(() => {
    // Initialize Mixpanel
    MixpanelManager.init();

    // Subscribe to auth state changes
    const unsubscribe = onAuthStateChange((user) => {
      const portalToken = getPortalToken();
      const nextUser =
        user ||
        (portalToken
          ? {
              uid: 'portal-device',
              displayName: 'Paired Omi device',
              email: null,
              photoURL: null,
            }
          : null);

      setUser(nextUser);
      setLoading(false);

      // Identify user with Mixpanel when authenticated
      if (nextUser && !previousUserRef.current) {
        MixpanelManager.identify(nextUser.uid, {
          name: nextUser.displayName || undefined,
          email: nextUser.email || undefined,
        });
      }

      previousUserRef.current = nextUser;
    });

    return () => unsubscribe();
  }, []);

  const handleSignOut = async () => {
    try {
      MixpanelManager.track('Sign Out');
      MixpanelManager.reset();
      await signOutUser();
      previousUserRef.current = null;
      setUser(null);
    } catch (error) {
      console.error('Failed to sign out:', error);
      throw error;
    }
  };

  const handleGetToken = async () => {
    return getIdToken();
  };

  const value: AuthContextType = {
    user,
    loading,
    signOut: handleSignOut,
    getToken: handleGetToken,
    isLoginPanelOpen,
    openLoginPanel,
    closeLoginPanel,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
