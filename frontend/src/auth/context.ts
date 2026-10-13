import { createContext } from 'react'
import type { User } from '../api/client'

export type SessionContextValue = {
  user: User | null
  loading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
}

export const SessionContext = createContext<SessionContextValue | null>(null)
