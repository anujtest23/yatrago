import { useState } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { initials } from '../lib/format';

interface NavItem {
  to: string;
  label: string;
  icon: string; // inline SVG path data
  superOnly?: boolean; // visible to super admins only
}

// Grouped nav so related admin functions sit together in the sidebar.
const NAV: { section: string; items: NavItem[] }[] = [
  {
    section: 'Overview',
    items: [
      { to: '/', label: 'Dashboard', icon: 'M3 12l9-9 9 9M5 10v10h14V10' },
    ],
  },
  {
    section: 'People',
    items: [
      { to: '/users', label: 'Users', icon: 'M16 14a4 4 0 10-8 0M12 7a3 3 0 100 6 3 3 0 000-6z' },
      { to: '/drivers', label: 'Driver Verification', icon: 'M5 13l4 4L19 7' },
      { to: '/vehicles', label: 'Vehicles', icon: 'M3 13l2-5h14l2 5v5H3v-5zM7 18v2M17 18v2' },
    ],
  },
  {
    section: 'Operations',
    items: [
      { to: '/trips', label: 'Trips', icon: 'M4 12h16M12 4l8 8-8 8' },
      { to: '/bookings', label: 'Bookings', icon: 'M5 4h14v16l-7-3-7 3z' },
      { to: '/payouts', label: 'Payouts', icon: 'M12 1v22M17 5H9a4 4 0 000 8h6a4 4 0 010 8H6' },
    ],
  },
  {
    section: 'Safety & Trust',
    items: [
      { to: '/sos', label: 'SOS Alerts', icon: 'M12 9v4M12 17h.01M10.3 3.9L1.8 18a2 2 0 001.7 3h17a2 2 0 001.7-3L13.7 3.9a2 2 0 00-3.4 0z' },
      { to: '/reports', label: 'Reports', icon: 'M4 4h16v12H5l-1 4z' },
    ],
  },
  {
    section: 'System',
    items: [
      { to: '/admins', label: 'Admins', icon: 'M16 14a4 4 0 10-8 0M12 7a3 3 0 100 6 3 3 0 000-6zM20 8v6M23 11h-6', superOnly: true },
      { to: '/config', label: 'Settings', icon: 'M12 15a3 3 0 100-6 3 3 0 000 6zM19 12a7 7 0 00-.1-1l2-1.5-2-3.4-2.3 1a7 7 0 00-1.7-1L14.5 3h-5l-.4 2.6a7 7 0 00-1.7 1l-2.3-1-2 3.4L5 11a7 7 0 000 2l-2 1.5 2 3.4 2.3-1a7 7 0 001.7 1l.4 2.6h5l.4-2.6a7 7 0 001.7-1l2.3 1 2-3.4-2-1.5a7 7 0 00.1-1z' },
      { to: '/audit-logs', label: 'Audit Logs', icon: 'M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2M9 12h6M9 16h6' },
    ],
  },
];

function Icon({ path }: { path: string }) {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      className="shrink-0"
    >
      <path d={path} />
    </svg>
  );
}

export function Layout() {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const [mobileOpen, setMobileOpen] = useState(false);

  const isSuper = user?.role === 'super_admin';
  // Hide super-admin-only entries (and any group left empty) for plain admins.
  const nav = NAV.map((g) => ({
    ...g,
    items: g.items.filter((i) => !i.superOnly || isSuper),
  })).filter((g) => g.items.length > 0);

  const handleSignOut = async () => {
    await signOut();
    navigate('/login');
  };

  const sidebar = (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 px-5 py-5">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-slate-900 text-sm font-bold text-white">
          Y
        </div>
        <div>
          <p className="text-sm font-semibold leading-tight text-white">
            YatraGo
          </p>
          <p className="text-[11px] leading-tight text-slate-400">
            Admin Console
          </p>
        </div>
      </div>

      <nav className="flex-1 space-y-5 overflow-y-auto px-3 pb-4">
        {nav.map((group) => (
          <div key={group.section}>
            <p className="px-2 pb-1 text-[10px] font-semibold uppercase tracking-wider text-slate-500">
              {group.section}
            </p>
            <div className="space-y-0.5">
              {group.items.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.to === '/'}
                  onClick={() => setMobileOpen(false)}
                  className={({ isActive }) =>
                    `flex items-center gap-3 rounded-lg px-2.5 py-2 text-sm font-medium transition ${
                      isActive
                        ? 'bg-slate-800 text-white'
                        : 'text-slate-300 hover:bg-slate-800/60 hover:text-white'
                    }`
                  }
                >
                  <Icon path={item.icon} />
                  {item.label}
                </NavLink>
              ))}
            </div>
          </div>
        ))}
      </nav>

      <div className="border-t border-slate-800 p-3">
        <div className="flex items-center gap-3 px-1 py-1">
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-slate-700 text-xs font-semibold text-white">
            {initials(user?.fullName ?? 'Admin')}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium text-white">
              {user?.fullName ?? 'Administrator'}
            </p>
            <p className="truncate text-[11px] text-slate-400">
              {user?.phoneNumber} ·{' '}
              {user?.role === 'super_admin' ? 'Super admin' : 'Admin'}
            </p>
          </div>
        </div>
        <button
          onClick={handleSignOut}
          className="mt-2 w-full rounded-lg px-2.5 py-2 text-left text-sm font-medium text-slate-300 hover:bg-slate-800 hover:text-white"
        >
          Sign out
        </button>
      </div>
    </div>
  );

  return (
    <div className="flex h-full">
      {/* Desktop sidebar */}
      <aside className="hidden w-64 shrink-0 bg-slate-900 lg:block">
        {sidebar}
      </aside>

      {/* Mobile drawer */}
      {mobileOpen && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div
            className="absolute inset-0 bg-slate-900/50"
            onClick={() => setMobileOpen(false)}
          />
          <aside className="absolute left-0 top-0 h-full w-64 bg-slate-900">
            {sidebar}
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center gap-3 border-b border-slate-200 bg-white px-4 py-3 lg:hidden">
          <button
            onClick={() => setMobileOpen(true)}
            className="rounded-lg p-1.5 text-slate-600 hover:bg-slate-100"
            aria-label="Open menu"
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path
                d="M4 6h16M4 12h16M4 18h16"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
              />
            </svg>
          </button>
          <span className="font-semibold text-slate-900">YatraGo Admin</span>
        </header>

        <main className="flex-1 overflow-y-auto p-5 lg:p-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
