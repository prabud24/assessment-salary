import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { EmployeeDetailPage } from './EmployeeDetailPage'
import { EmployeeFormPage } from './EmployeeFormPage'
import { EmployeeListPage } from './EmployeeListPage'
import { InsightsPage } from './InsightsPage'
import { jsonResponse, renderPage } from '../test/render'
import { setCsrfToken } from '../api/client'

const employee = {
  id: 12,
  employee_number: 'EMP00012',
  name: 'Mira Shah',
  email: 'mira@example.com',
  country_code: 'IN',
  department: 'Finance',
  status: 'active' as const,
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
}

afterEach(() => {
  vi.unstubAllGlobals()
  setCsrfToken(null)
})

describe('employee list', () => {
  it('renders results and applies search and filter query parameters', async () => {
    const requested: string[] = []
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input)
      requested.push(url)
      return jsonResponse({
        employees: [employee],
        pagination: { page: 1, per_page: 25, total_count: 1, total_pages: 1 },
      })
    }))

    renderPage(<EmployeeListPage />)
    expect(await screen.findByText('EMP00012')).toBeInTheDocument()
    fireEvent.change(screen.getByLabelText('Search employees'), { target: { value: 'Mira' } })
    fireEvent.change(screen.getByLabelText('Country'), { target: { value: 'IN' } })

    await waitFor(() => expect(requested.at(-1)).toContain('q=Mira'))
    expect(requested.at(-1)).toContain('country=IN')
    expect(screen.getByText('Mira Shah')).toBeInTheDocument()
  })

  it('shows an empty state when there are no matching employees', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(jsonResponse({
      employees: [],
      pagination: { page: 1, per_page: 25, total_count: 0, total_pages: 0 },
    })))

    renderPage(<EmployeeListPage />)

    expect(await screen.findByText('No employees match these filters.')).toBeInTheDocument()
  })
})

describe('employee form', () => {
  it('displays server validation errors beside the corresponding fields', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(jsonResponse({
      errors: {
        employee_number: ['has already been taken'],
        email: ['has already been taken'],
      },
    }, 422)))

    renderPage(<EmployeeFormPage />, '/employees/new')
    fireEvent.change(screen.getByLabelText(/Employee number/), { target: { value: 'EMP00012' } })
    fireEvent.change(screen.getByLabelText(/Name/), { target: { value: 'Mira Shah' } })
    fireEvent.change(screen.getByLabelText(/Email/), { target: { value: 'mira@example.com' } })
    fireEvent.change(screen.getByLabelText(/Country code/), { target: { value: 'IN' } })
    fireEvent.change(screen.getByLabelText(/Department/), { target: { value: 'Finance' } })
    fireEvent.click(screen.getByRole('button', { name: 'Create employee' }))

    expect(await screen.findAllByText('has already been taken')).toHaveLength(2)
    expect(screen.getByLabelText(/Employee number/)).toHaveAttribute('aria-invalid', 'true')
    expect(screen.getByLabelText(/Email/)).toHaveAttribute('aria-invalid', 'true')
  })
})

describe('employee detail and salary history', () => {
  it('shows salary history and confirms the requested salary change before posting', async () => {
    const history = [{
      annual_salary: '50000.125',
      currency: 'USD',
      effective_from: '2025-01-01',
      effective_to: null,
      created_at: '2025-01-01T00:00:00Z',
      updated_at: '2025-01-01T00:00:00Z',
    }]
    const requests: { url: string; init?: RequestInit }[] = []
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input)
      requests.push({ url, init })
      if (url === '/api/v1/employees/12/salary_records' && init?.method === 'POST') {
        return jsonResponse({ salary_record: { ...history[0], annual_salary: '60000.125', effective_from: '2099-01-01' } }, 201)
      }
      if (url === '/api/v1/employees/12') return jsonResponse({ employee })
      if (url === '/api/v1/employees/12/salary_records') return jsonResponse({ salary_records: history })
      throw new Error(`Unexpected request: ${url}`)
    }))
    setCsrfToken('salary-csrf')

    renderPage(<EmployeeDetailPage />, '/employees/12', '/employees/:id')
    expect(await screen.findByText('USD 50,000.125')).toBeInTheDocument()
    expect(screen.getByText('01 Jan 2025')).toBeInTheDocument()
    fireEvent.change(screen.getByLabelText(/Annual salary/), { target: { value: '60000.125' } })
    fireEvent.change(screen.getByLabelText(/Currency/), { target: { value: 'USD' } })
    fireEvent.change(screen.getByLabelText(/Effective from/), { target: { value: '2099-01-01' } })
    fireEvent.click(screen.getByRole('button', { name: 'Review salary change' }))

    expect(await screen.findByRole('dialog')).toHaveTextContent('01 Jan 2099')
    fireEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Confirm change' }))

    await waitFor(() => {
      expect(requests.some(({ init }) => init?.method === 'POST')).toBe(true)
    })
    const post = requests.find(({ init }) => init?.method === 'POST')
    expect(post?.init?.body).toBe(JSON.stringify({
      salary_record: { annual_salary: '60000.125', currency: 'USD', effective_from: '2099-01-01' },
    }))
    expect(new Headers(post?.init?.headers).get('X-CSRF-Token')).toBe('salary-csrf')
    expect(await screen.findByText('Salary change recorded.')).toBeInTheDocument()
  })
})

describe('insights', () => {
  it('renders currency-separated summaries and submits the selected range for salary increase events', async () => {
    const requests: string[] = []
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input)
      requests.push(url)
      if (url.endsWith('/average_salary_by_country')) {
        return jsonResponse({ results: [{ country: 'IN', currency: 'USD', average_salary: '50000.125', employee_count: 2 }] })
      }
      if (url.endsWith('/total_salary_by_department')) {
        return jsonResponse({ results: [{ department: 'Finance', currency: 'EUR', total_salary: '90000.50', employee_count: 1 }] })
      }
      if (url.includes('/salary_increases?')) {
        return jsonResponse({ results: [{ currency: 'USD', increase_count: 3 }] })
      }
      throw new Error(`Unexpected request: ${url}`)
    }))

    renderPage(<InsightsPage />)
    expect(await screen.findByText('USD 50,000.125')).toBeInTheDocument()
    expect(screen.getByText('EUR 90,000.50')).toBeInTheDocument()
    fireEvent.change(screen.getByLabelText(/Start date/), { target: { value: '2026-01-01' } })
    fireEvent.change(screen.getByLabelText(/End date/), { target: { value: '2026-02-01' } })
    fireEvent.click(screen.getByRole('button', { name: 'Run report' }))

    expect(await screen.findByText('3')).toBeInTheDocument()
    expect(requests.some((url) => url.includes('start=2026-01-01') && url.includes('end=2026-02-01'))).toBe(true)
    expect(screen.getByRole('heading', { name: 'Salary increase events' })).toBeInTheDocument()
  })
})
