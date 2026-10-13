import { afterEach, describe, expect, it, vi } from 'vitest'
import { apiRequest, setCsrfToken, setUnauthorizedHandler } from './client'

describe('API client', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    setCsrfToken(null)
    setUnauthorizedHandler(null)
  })

  it('includes cookies and the in-memory CSRF header on state-changing requests', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ employee: { id: 1 } }), {
      status: 201,
      headers: { 'Content-Type': 'application/json' },
    }))
    vi.stubGlobal('fetch', fetchMock)
    setCsrfToken('csrf-in-memory')

    await apiRequest('/employees', { method: 'POST', body: { employee: { name: 'Asha' } } })

    const [url, options] = fetchMock.mock.calls[0] as [string, RequestInit]
    const headers = new Headers(options.headers)
    expect(url).toBe('/api/v1/employees')
    expect(options).toMatchObject({
      method: 'POST',
      credentials: 'include',
      body: JSON.stringify({ employee: { name: 'Asha' } }),
    })
    expect(headers.get('Accept')).toBe('application/json')
    expect(headers.get('Content-Type')).toBe('application/json')
    expect(headers.get('X-CSRF-Token')).toBe('csrf-in-memory')
  })

  it('does not add a CSRF header to safe GET requests', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ results: [] }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }))
    vi.stubGlobal('fetch', fetchMock)
    setCsrfToken('csrf-in-memory')

    await apiRequest('/employees')

    const [, options] = fetchMock.mock.calls[0] as [string, RequestInit]
    expect(options).toMatchObject({ method: 'GET', credentials: 'include' })
    expect(new Headers(options.headers).has('X-CSRF-Token')).toBe(false)
  })

  it('signals unauthorized protected responses without retrying the request', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ errors: { base: ['Authentication required'] } }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    }))
    const onUnauthorized = vi.fn()
    vi.stubGlobal('fetch', fetchMock)
    setUnauthorizedHandler(onUnauthorized)

    await expect(apiRequest('/employees')).rejects.toMatchObject({ status: 401 })

    expect(onUnauthorized).toHaveBeenCalledOnce()
    expect(fetchMock).toHaveBeenCalledOnce()
  })

  it('clears the client session when logout reports an expired session', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ errors: { base: ['Authentication required'] } }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    }))
    const onUnauthorized = vi.fn()
    vi.stubGlobal('fetch', fetchMock)
    setUnauthorizedHandler(onUnauthorized)

    await expect(apiRequest('/session', { method: 'DELETE' })).rejects.toMatchObject({ status: 401 })

    expect(onUnauthorized).toHaveBeenCalledOnce()
    expect(fetchMock).toHaveBeenCalledOnce()
  })
})
