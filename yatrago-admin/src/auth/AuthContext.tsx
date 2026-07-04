import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import { tokenStore } from '../api/client';
import { logout as apiLogout, verifyAdminAccess } from '../api/auth';
import type { AdminUser } from '../api/types';

interface AuthState {
  user: AdminUser | null;
  ready: boolean; // finished the boot-time access check
  isAuthed: boolean;
  setSession: (user: AdminUser) => void;
  signOut: () => Promise<void>;
}

const AuthCtx = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(tokenStore.user);
  const [ready, setReady] = useState(false);

  // On boot: if we hold a token, confirm it still grants admin access.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (tokenStore.access) {
        const ok = await verifyAdminAccess();
        if (cancelled) return;
        if (ok) {
          setUser(tokenStore.user);
        } else {
          tokenStore.clear();
          setUser(null);
        }
      }
      if (!cancelled) setReady(true);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const signOut = async () => {
    await apiLogout();
    setUser(null);
  };

  return (
    <AuthCtx.Provider
      value={{
        user,
        ready,
        isAuthed: !!user && !!tokenStore.access,
        setSession: setUser,
        signOut,
      }}
    >
      {children}
    </AuthCtx.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthState {
  const ctx = useContext(AuthCtx);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
