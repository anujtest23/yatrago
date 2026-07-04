import axios, {
  type AxiosError,
  type AxiosRequestConfig,
  type InternalAxiosRequestConfig,
} from 'axios';

// Token storage keys — kept in localStorage so a refresh survives page reloads.
const ACCESS_KEY = 'yatrago_admin_access';
const REFRESH_KEY = 'yatrago_admin_refresh';
const USER_KEY = 'yatrago_admin_user';

export const tokenStore = {
  get access() {
    return localStorage.getItem(ACCESS_KEY);
  },
  get refresh() {
    return localStorage.getItem(REFRESH_KEY);
  },
  get user() {
    const raw = localStorage.getItem(USER_KEY);
    return raw ? JSON.parse(raw) : null;
  },
  set(access: string, refresh: string, user: unknown) {
    localStorage.setItem(ACCESS_KEY, access);
    localStorage.setItem(REFRESH_KEY, refresh);
    localStorage.setItem(USER_KEY, JSON.stringify(user));
  },
  clear() {
    localStorage.removeItem(ACCESS_KEY);
    localStorage.removeItem(REFRESH_KEY);
    localStorage.removeItem(USER_KEY);
  },
};

export const api = axios.create({
  baseURL: '/api/v1',
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const token = tokenStore.access;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Single-flight refresh: if a 401 comes back, try to rotate the refresh
// token once. Concurrent 401s share the same refresh promise.
let refreshing: Promise<string | null> | null = null;

async function doRefresh(): Promise<string | null> {
  const refresh = tokenStore.refresh;
  if (!refresh) return null;
  try {
    const res = await axios.post('/api/v1/auth/refresh', {
      refreshToken: refresh,
    });
    // Raw axios (not the `api` instance) — unwrap the envelope manually.
    const payload = unwrap(res.data) as {
      accessToken: string;
      refreshToken: string;
    };
    tokenStore.set(payload.accessToken, payload.refreshToken, tokenStore.user);
    return payload.accessToken;
  } catch {
    tokenStore.clear();
    return null;
  }
}

// The API wraps every success in { success, data, message }. Unwrap it here
// so callers work with the payload directly.
function unwrap(body: unknown): unknown {
  if (
    body &&
    typeof body === 'object' &&
    'success' in body &&
    'data' in body
  ) {
    return (body as { data: unknown }).data;
  }
  return body;
}

api.interceptors.response.use(
  (r) => {
    r.data = unwrap(r.data);
    return r;
  },
  async (error: AxiosError) => {
    const original = error.config as AxiosRequestConfig & { _retry?: boolean };
    const status = error.response?.status;

    if (status === 401 && original && !original._retry) {
      original._retry = true;
      refreshing = refreshing ?? doRefresh();
      const newToken = await refreshing;
      refreshing = null;
      if (newToken) {
        original.headers = original.headers ?? {};
        (original.headers as Record<string, string>).Authorization =
          `Bearer ${newToken}`;
        return api(original);
      }
      // Refresh failed — force logout by redirecting to login.
      if (window.location.pathname !== '/login') {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  },
);

// Pull a human-readable message out of an axios error for toasts / alerts.
export function errorMessage(err: unknown): string {
  if (axios.isAxiosError(err)) {
    const data = err.response?.data as { message?: string | string[] } | undefined;
    if (data?.message) {
      return Array.isArray(data.message) ? data.message.join(', ') : data.message;
    }
    return err.message;
  }
  return err instanceof Error ? err.message : 'Something went wrong';
}

// Resolve a stored document/file URL to something the browser can load.
// Backend serves uploads at /uploads (proxied in dev). Absolute URLs pass
// through untouched.
export function resolveFileUrl(url?: string | null): string | null {
  if (!url) return null;
  if (/^https?:\/\//i.test(url)) return url;
  if (url.startsWith('/uploads')) return url;
  return `/uploads/${url.replace(/^\/+/, '')}`;
}
