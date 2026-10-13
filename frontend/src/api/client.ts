export type User = { id: number; email: string }

export type Employee = {
  id: number
  employee_number: string
  name: string
  email: string
  country_code: string
  department: string
  status: 'active' | 'inactive'
  created_at: string
  updated_at: string
}

export type SalaryRecord = {
  annual_salary: string
  currency: string
  effective_from: string
  effective_to: string | null
  created_at: string
  updated_at: string
}

export type Pagination = {
  page: number
  per_page: number
  total_count: number
  total_pages: number
}

export type EmployeeAttributes = Pick<
  Employee,
  'employee_number' | 'name' | 'email' | 'country_code' | 'department' | 'status'
>

export type FieldErrors = Record<string, string[]>

export class ApiError extends Error {
  readonly status: number
  readonly errors: FieldErrors

  constructor(
    message: string,
    status: number,
    errors: FieldErrors = {},
  ) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.errors = errors
  }
}

let csrfToken: string | null = null
let unauthorizedHandler: (() => void) | null = null

export function setCsrfToken(token: string | null) {
  csrfToken = token
}

export function setUnauthorizedHandler(handler: (() => void) | null) {
  unauthorizedHandler = handler
}

type RequestOptions = {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE'
  body?: unknown
}

export async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const method = options.method ?? 'GET'
  const headers = new Headers({ Accept: 'application/json' })
  if (options.body !== undefined) headers.set('Content-Type', 'application/json')
  if (method !== 'GET' && csrfToken) headers.set('X-CSRF-Token', csrfToken)

  const response = await fetch(`/api/v1${path}`, {
    method,
    credentials: 'include',
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  })

  const payload: unknown = response.status === 204 ? null : await response.json().catch(() => null)
  if (!response.ok) {
    const errors = getFieldErrors(payload)
    const error = new ApiError(firstError(errors) ?? `Request failed (${response.status})`, response.status, errors)
    if (response.status === 401 && (path !== '/session' || method === 'DELETE')) unauthorizedHandler?.()
    throw error
  }
  return payload as T
}

function getFieldErrors(payload: unknown): FieldErrors {
  if (!payload || typeof payload !== 'object' || !('errors' in payload)) return {}
  const errors = (payload as { errors?: unknown }).errors
  if (!errors || typeof errors !== 'object') return {}
  return Object.fromEntries(
    Object.entries(errors).map(([field, messages]) => [
      field,
      Array.isArray(messages) ? messages.map(String) : [String(messages)],
    ]),
  )
}

function firstError(errors: FieldErrors) {
  return Object.values(errors).flat()[0]
}
