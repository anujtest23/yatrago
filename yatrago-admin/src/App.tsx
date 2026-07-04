import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import { Layout } from './components/Layout';
import { Spinner } from './components/ui';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Users from './pages/Users';
import Drivers from './pages/Drivers';
import Vehicles from './pages/Vehicles';
import Trips from './pages/Trips';
import Bookings from './pages/Bookings';
import Payouts from './pages/Payouts';
import Sos from './pages/Sos';
import Reports from './pages/Reports';
import Config from './pages/Config';
import AuditLogs from './pages/AuditLogs';
import Admins from './pages/Admins';

function Protected({ children }: { children: React.ReactNode }) {
  const { isAuthed, ready } = useAuth();
  if (!ready) {
    return (
      <div className="flex h-full items-center justify-center">
        <Spinner />
      </div>
    );
  }
  return isAuthed ? <>{children}</> : <Navigate to="/login" replace />;
}

// Route-level guard: super-admin-only pages redirect everyone else home.
function SuperOnly({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  return user?.role === 'super_admin' ? (
    <>{children}</>
  ) : (
    <Navigate to="/" replace />
  );
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        element={
          <Protected>
            <Layout />
          </Protected>
        }
      >
        <Route path="/" element={<Dashboard />} />
        <Route path="/users" element={<Users />} />
        <Route path="/drivers" element={<Drivers />} />
        <Route path="/vehicles" element={<Vehicles />} />
        <Route path="/trips" element={<Trips />} />
        <Route path="/bookings" element={<Bookings />} />
        <Route path="/payouts" element={<Payouts />} />
        <Route path="/sos" element={<Sos />} />
        <Route path="/reports" element={<Reports />} />
        <Route
          path="/admins"
          element={
            <SuperOnly>
              <Admins />
            </SuperOnly>
          }
        />
        <Route path="/config" element={<Config />} />
        <Route path="/audit-logs" element={<AuditLogs />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
