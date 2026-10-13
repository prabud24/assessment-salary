import { fireEvent, screen, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { jsonResponse, renderApp } from '../test/render'

describe('session and protected navigation', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('redirects anonymous users to login and allows login with the bootstrap CSRF token', async () => {
    const calls: { url: string; init?: RequestInit }[] = []
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input)
      calls.push({ url, init })
      if (url === '/api/v1/session' && init?.method === 'POST') {
        expect(new Headers(init.headers).get('X-CSRF-Token')).toBe('bootstrap-token')
        return jsonResponse({ user: { id: 7, email: 'hr@example.com' }, csrf_token: 'logged-in-token' })
      }
      if (url === '/api/v1/session') return jsonResponse({ user: null, csrf_token: 'bootstrap-token' })
      if (url.startsWith('/api/v1/employees')) {
        return jsonResponse({
          employees: [{
            id: 2, employee_number: 'EMP00002', name: 'Asha Rao', email: 'asha@example.com',
            country_code: 'IN', department: 'People', status: 'active',
            created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z',
          }],
          pagination: { page: 1, per_page: 25, total_count: 1, total_pages: 1 },
        })
      }
      throw new Error(`Unexpected request: ${url}`)
    }))

    renderApp('/employees')

    expect(await screen.findByRole('heading', { name: 'Welcome back' })).toBeInTheDocument()
    fireEvent.change(screen.getByRole('textbox', { name: /Email/ }), { target: { value: 'hr@example.com' } })
    fireEvent.change(screen.getByLabelText(/Password/), { target: { value: 'secret-password' } })
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByText('EMP00002')).toBeInTheDocument()
    expect(calls.some(({ url, init }) => url === '/api/v1/session' && init?.method === 'POST')).toBe(true)
    expect(calls.some(({ url }) => url === '/api/v1/employees?page=1&per_page=25')).toBe(true)
  })

  it('shows an invalid credentials error and stays on the login page', async () => {
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      if (String(input) === '/api/v1/session' && init?.method === 'POST') {
        return jsonResponse({ errors: { base: ['Invalid email or password'] } }, 401)
      }
      return jsonResponse({ user: null, csrf_token: 'csrf-token' })
    }))

    renderApp('/employees')
    await screen.findByRole('heading', { name: 'Welcome back' })
    fireEvent.change(screen.getByRole('textbox', { name: /Email/ }), { target: { value: 'hr@example.com' } })
    fireEvent.change(screen.getByLabelText(/Password/), { target: { value: 'wrong' } })
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Invalid email or password')
    expect(screen.getByRole('heading', { name: 'Welcome back' })).toBeInTheDocument()
  })

  it('logs out and returns to the login page', async () => {
    let loggedIn = true
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input)
      if (url === '/api/v1/session' && init?.method === 'DELETE') {
        loggedIn = false
        return jsonResponse({ user: null, csrf_token: 'after-logout' })
      }
      if (url === '/api/v1/session') {
        return jsonResponse({ user: loggedIn ? { id: 1, email: 'hr@example.com' } : null, csrf_token: 'csrf-token' })
      }
      if (url.startsWith('/api/v1/employees')) {
        return jsonResponse({ employees: [], pagination: { page: 1, per_page: 25, total_count: 0, total_pages: 0 } })
      }
      throw new Error(`Unexpected request: ${url}`)
    }))

    renderApp('/employees')
    fireEvent.click(await screen.findByRole('button', { name: 'Open navigation' }))
    await screen.findByRole('button', { name: 'Log out' })
    fireEvent.click(screen.getByRole('button', { name: 'Log out' }))

    expect(await screen.findByRole('heading', { name: 'Welcome back' })).toBeInTheDocument()
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Log out' })).not.toBeInTheDocument())
  })
})
