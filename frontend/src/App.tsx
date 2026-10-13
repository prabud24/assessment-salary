import { lazy, Suspense } from 'react'
import { Box, CircularProgress } from '@mui/material'
import { Navigate, Outlet, Route, Routes, useLocation } from 'react-router-dom'
import { useSession } from './auth/useSession'
import { AppLayout } from './components/AppLayout'

const LoginPage = lazy(() => import('./pages/LoginPage').then((page) => ({ default: page.LoginPage })))
const EmployeeDetailPage = lazy(() => import('./pages/EmployeeDetailPage').then((page) => ({ default: page.EmployeeDetailPage })))
const EmployeeFormPage = lazy(() => import('./pages/EmployeeFormPage').then((page) => ({ default: page.EmployeeFormPage })))
const EmployeeListPage = lazy(() => import('./pages/EmployeeListPage').then((page) => ({ default: page.EmployeeListPage })))
const InsightsPage = lazy(() => import('./pages/InsightsPage').then((page) => ({ default: page.InsightsPage })))

function PageFallback() {
  return <Box sx={{ minHeight: 240, display: 'grid', placeItems: 'center' }}><CircularProgress aria-label="Loading page" /></Box>
}

function ProtectedRoute() {
  const { user, loading } = useSession()
  const location = useLocation()
  if (loading) {
    return <Box sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}><CircularProgress aria-label="Loading session" /></Box>
  }
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />
  return <Outlet />
}

export default function App() {
  return (
    <Suspense fallback={<PageFallback />}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route element={<ProtectedRoute />}>
          <Route element={<AppLayout />}>
            <Route index element={<Navigate to="/employees" replace />} />
            <Route path="/employees" element={<EmployeeListPage />} />
            <Route path="/employees/new" element={<EmployeeFormPage />} />
            <Route path="/employees/:id" element={<EmployeeDetailPage />} />
            <Route path="/employees/:id/edit" element={<EmployeeFormPage />} />
            <Route path="/insights" element={<InsightsPage />} />
          </Route>
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Suspense>
  )
}
