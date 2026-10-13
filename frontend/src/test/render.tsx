import { CssBaseline, ThemeProvider } from '@mui/material'
import { render } from '@testing-library/react'
import type { ReactElement } from 'react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import App from '../App'
import { SessionProvider } from '../auth/SessionContext'
import { theme } from '../theme'

export function renderPage(ui: ReactElement, route = '/', routePattern = '*') {
  return render(
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <MemoryRouter initialEntries={[route]}>
        <Routes><Route path={routePattern} element={ui} /></Routes>
      </MemoryRouter>
    </ThemeProvider>,
  )
}

export function renderApp(route = '/') {
  return render(
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <MemoryRouter initialEntries={[route]}>
        <SessionProvider><App /></SessionProvider>
      </MemoryRouter>
    </ThemeProvider>,
  )
}

export function jsonResponse(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
