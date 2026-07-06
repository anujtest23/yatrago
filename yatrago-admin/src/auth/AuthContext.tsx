import {
  createContext,
  useContext,
  useEffect,
  useRef,
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

// Admin consoles get left open on unattended machines; 30 idle minutes
// end the session locally AND revoke it server-side (via signOut). The
// backend independently enforces its own inactivity timeout on refresh.
const IDLE_TIMEOUT_MS = 30 * 60_000;
const IDLE_CHECK_INTERVAL_MS = 60_000;
const ACTIVITY_EVENTS = [
  'mousemove',
  'mousedown',
  'keydown',
  'scroll',
  'touchstart',
] as const;

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

  // Idle-timeout auto-logout while a session is active.
  const lastActivity = useRef(Date.now());
  useEffect(() => {
    if (!user) return;
    const touch = () => {
      lastActivity.current = Date.now();
    };
    ACTIVITY_EVENTS.forEach((e) =>
      window.addEventListener(e, touch, { passive: true }),
    );
    const timer = window.setInterval(() => {
      if (Date.now() - lastActivity.current >= IDLE_TIMEOUT_MS) {
        void signOut();
      }
    }, IDLE_CHECK_INTERVAL_MS);
    return () => {
      ACTIVITY_EVENTS.forEach((e) => window.removeEventListener(e, touch));
      window.clearInterval(timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

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
