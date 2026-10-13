import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import {
  Alert, Box, Button, Card, CardContent, CircularProgress, Stack, Table, TableBody,
  TableCell, TableContainer, TableHead, TableRow, TextField, Typography,
} from '@mui/material'
import { ApiError, apiRequest } from '../api/client'
import { FormErrors } from '../components/FieldError'
import { dateDaysBefore, formatMoney, isValidIsoDate, kolkataToday } from '../lib/format'

type CountryAverage = { country: string; currency: string; average_salary: string; employee_count: number }
type DepartmentTotal = { department: string; currency: string; total_salary: string; employee_count: number }
type SalaryIncreaseCount = { currency: string; increase_count: number }
type Results<T> = { results: T[] }

export function InsightsPage() {
  const today = kolkataToday()
  const [averages, setAverages] = useState<CountryAverage[]>([])
  const [totals, setTotals] = useState<DepartmentTotal[]>([])
  const [summaryLoading, setSummaryLoading] = useState(true)
  const [summaryError, setSummaryError] = useState('')
  const [start, setStart] = useState(dateDaysBefore(today, 365))
  const [end, setEnd] = useState(today)
  const [increases, setIncreases] = useState<SalaryIncreaseCount[] | null>(null)
  const [increaseLoading, setIncreaseLoading] = useState(false)
  const [increaseError, setIncreaseError] = useState('')
  const [dateErrors, setDateErrors] = useState<string[]>([])

  useEffect(() => {
    let current = true
    Promise.all([
      apiRequest<Results<CountryAverage>>('/insights/average_salary_by_country'),
      apiRequest<Results<DepartmentTotal>>('/insights/total_salary_by_department'),
    ])
      .then(([averageResponse, totalResponse]) => {
        if (current) {
          setAverages(averageResponse.results)
          setTotals(totalResponse.results)
        }
      })
      .catch((cause: unknown) => {
        if (current) setSummaryError(cause instanceof Error ? cause.message : 'Unable to load salary summaries.')
      })
      .finally(() => { if (current) setSummaryLoading(false) })
    return () => { current = false }
  }, [])

  async function loadIncreases(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const errors: string[] = []
    if (!start) errors.push('Start date is required.')
    if (!end) errors.push('End date is required.')
    if (start && !isValidIsoDate(start)) errors.push('Start date must be valid.')
    if (end && !isValidIsoDate(end)) errors.push('End date must be valid.')
    if (isValidIsoDate(start) && isValidIsoDate(end) && start >= end) errors.push('End date must be after the start date.')
    setDateErrors(errors)
    setIncreaseError('')
    if (errors.length) return

    setIncreaseLoading(true)
    const params = new URLSearchParams({ start, end })
    try {
      const response = await apiRequest<Results<SalaryIncreaseCount>>(`/insights/salary_increases?${params}`)
      setIncreases(response.results)
    } catch (cause) {
      if (cause instanceof ApiError) setIncreaseError(cause.message)
      else setIncreaseError('Unable to load salary increase events.')
    } finally {
      setIncreaseLoading(false)
    }
  }

  return (
    <Stack spacing={3}>
      <Box>
        <Typography variant="h4">Insights</Typography>
        <Typography color="text.secondary">Current annual salary summaries and historical salary increase events.</Typography>
      </Box>
      {summaryError && <Alert severity="error" role="alert">{summaryError}</Alert>}
      {summaryLoading ? (
        <Box sx={{ minHeight: 180, display: 'grid', placeItems: 'center' }}><CircularProgress aria-label="Loading salary insights" /></Box>
      ) : summaryError ? null : (
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', xl: '1fr 1fr' }, gap: 3 }}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>Average current salary by country</Typography>
              <SummaryTable
                label="Average salary by country and currency"
                empty="No current salaries to summarize."
                headings={['Country', 'Currency', 'Average annual salary', 'Employees']}
                rows={averages.map((row) => [row.country, row.currency, formatMoney(row.average_salary, row.currency), String(row.employee_count)])}
              />
            </CardContent>
          </Card>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>Total current salary by department</Typography>
              <SummaryTable
                label="Total salary by department and currency"
                empty="No current salaries to summarize."
                headings={['Department', 'Currency', 'Total annual salary', 'Employees']}
                rows={totals.map((row) => [row.department, row.currency, formatMoney(row.total_salary, row.currency), String(row.employee_count)])}
              />
            </CardContent>
          </Card>
        </Box>
      )}
      <Card>
        <CardContent>
          <Stack spacing={2}>
            <Box>
              <Typography variant="h6">Salary increase events</Typography>
              <Typography variant="body2" color="text.secondary">
                Counts returned by the API, grouped by currency, for the start-inclusive and end-exclusive date range.
              </Typography>
            </Box>
            <Stack component="form" direction={{ xs: 'column', sm: 'row' }} spacing={2} onSubmit={loadIncreases} noValidate>
              <TextField
                label="Start date"
                type="date"
                value={start}
                onChange={(event) => setStart(event.target.value)}
                error={dateErrors.some((message) => message.includes('Start'))}
                slotProps={{ inputLabel: { shrink: true } }}
                required
              />
              <TextField
                label="End date (exclusive)"
                type="date"
                value={end}
                onChange={(event) => setEnd(event.target.value)}
                error={dateErrors.some((message) => message.includes('End'))}
                slotProps={{ inputLabel: { shrink: true } }}
                required
              />
              <Button type="submit" variant="contained" disabled={increaseLoading}>Run report</Button>
            </Stack>
            {dateErrors.map((message) => <FormErrors key={message} errors={{ base: [message] }} />)}
            {increaseError && <Alert severity="error" role="alert">{increaseError}</Alert>}
            {increaseLoading && <CircularProgress aria-label="Loading salary increase events" />}
            {increases && !increaseLoading && (
              <SummaryTable
                label="Salary increase events by currency"
                empty="No salary increase events in this date range."
                headings={['Currency', 'Salary increase events']}
                rows={increases.map((row) => [row.currency, String(row.increase_count)])}
              />
            )}
          </Stack>
        </CardContent>
      </Card>
    </Stack>
  )
}

function SummaryTable({
  label,
  empty,
  headings,
  rows,
}: {
  label: string
  empty: string
  headings: string[]
  rows: string[][]
}) {
  if (!rows.length) return <Typography color="text.secondary">{empty}</Typography>
  return (
    <TableContainer>
      <Table size="small" aria-label={label}>
        <TableHead><TableRow>{headings.map((heading) => <TableCell key={heading}>{heading}</TableCell>)}</TableRow></TableHead>
        <TableBody>
          {rows.map((row, index) => (
            <TableRow key={`${row[0]}-${row[1]}-${index}`}>
              {row.map((value, cellIndex) => <TableCell key={`${cellIndex}-${value}`}>{value}</TableCell>)}
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  )
}
