import { useCallback, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { apiRequest, setCsrfToken, setUnauthorizedHandler } from '../api/client'
import type { User } from '../api/client'
import { SessionContext } from './context'

type SessionResponse = { user: User | null; csrf_token: string }

export function SessionProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let mounted = true
    setUnauthorizedHandler(() => {
      setCsrfToken(null)
      setUser(null)
    })
    apiRequest<SessionResponse>('/session')
      .then((session) => {
        if (!mounted) return
        setCsrfToken(session.csrf_token)
        setUser(session.user)
      })
      .catch(() => {
        if (mounted) {
          setCsrfToken(null)
          setUser(null)
        }
      })
      .finally(() => {
        if (mounted) setLoading(false)
      })
    return () => {
      mounted = false
      setUnauthorizedHandler(null)
    }
  }, [])

  const login = useCallback(async (email: string, password: string) => {
    const session = await apiRequest<SessionResponse>('/session', {
      method: 'POST',
      body: { email, password },
    })
    setCsrfToken(session.csrf_token)
    setUser(session.user)
  }, [])

  const logout = useCallback(async () => {
    const session = await apiRequest<SessionResponse>('/session', { method: 'DELETE' })
    setCsrfToken(session.csrf_token)
    setUser(null)
  }, [])

  const value = useMemo(() => ({ user, loading, login, logout }), [user, loading, login, logout])
  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
}
