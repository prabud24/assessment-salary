import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import {
  Alert, Box, Button, Card, CardContent, CircularProgress, Dialog, DialogActions, DialogContent,
  DialogContentText, DialogTitle, Stack, Table, TableBody, TableCell, TableContainer, TableHead,
  TableRow, TextField, Typography,
} from '@mui/material'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import { Link as RouterLink, useParams } from 'react-router-dom'
import { ApiError, apiRequest } from '../api/client'
import type { Employee, FieldErrors, SalaryRecord } from '../api/client'
import { FormErrors } from '../components/FieldError'
import { formatDate, formatMoney, isValidIsoDate, kolkataToday } from '../lib/format'

type SalaryFields = { annual_salary: string; currency: string; effective_from: string }

function fetchEmployeeDetails(id: string) {
  return Promise.all([
    apiRequest<{ employee: Employee }>(`/employees/${id}`),
    apiRequest<{ salary_records: SalaryRecord[] }>(`/employees/${id}/salary_records`),
  ])
}

export function EmployeeDetailPage() {
  const { id } = useParams()
  const [employee, setEmployee] = useState<Employee | null>(null)
  const [salaryRecords, setSalaryRecords] = useState<SalaryRecord[]>([])
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState('')
  const [salary, setSalary] = useState<SalaryFields>({ annual_salary: '', currency: '', effective_from: '' })
  const [errors, setErrors] = useState<FieldErrors>({})
  const [clientError, setClientError] = useState('')
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [successMessage, setSuccessMessage] = useState('')

  const latestStart = useMemo(() => salaryRecords[0]?.effective_from ?? null, [salaryRecords])

  useEffect(() => {
    let current = true
    if (!id) return () => { current = false }
    fetchEmployeeDetails(id)
      .then(([employeeResponse, historyResponse]) => {
        if (!current) return
        setEmployee(employeeResponse.employee)
        setSalaryRecords(historyResponse.salary_records)
        setLoadError('')
      })
      .catch((cause: unknown) => {
        if (current) setLoadError(cause instanceof Error ? cause.message : 'Unable to load employee details.')
      })
      .finally(() => {
        if (current) setLoading(false)
      })
    return () => { current = false }
  }, [id])

  async function load() {
    if (!id) return
    try {
      const [employeeResponse, historyResponse] = await fetchEmployeeDetails(id)
      setEmployee(employeeResponse.employee)
      setSalaryRecords(historyResponse.salary_records)
      setLoadError('')
    } catch (cause) {
      setLoadError(cause instanceof Error ? cause.message : 'Unable to load employee details.')
    } finally {
      setLoading(false)
    }
  }

  function updateSalary(field: keyof SalaryFields, value: string) {
    setSalary((previous) => ({ ...previous, [field]: value }))
    setErrors((previous) => ({ ...previous, [field]: [] }))
  }

  function validateSalary() {
    const nextErrors: FieldErrors = {}
    const today = kolkataToday()
    if (!salary.annual_salary.trim() || !/^\d+(\.\d{1,3})?$/.test(salary.annual_salary) || /^0+(\.0+)?$/.test(salary.annual_salary)) {
      nextErrors.annual_salary = ['must be a positive amount with up to 3 decimal places']
    }
    if (!/^[A-Za-z]{3}$/.test(salary.currency)) nextErrors.currency = ['must be a three-letter currency code']
    if (!salary.effective_from) nextErrors.effective_from = ['is required']
    else if (!isValidIsoDate(salary.effective_from)) {
      nextErrors.effective_from = ['must be a valid date']
    } else if (salary.effective_from < today) {
      nextErrors.effective_from = ['must be today or a future date']
    } else if (latestStart && salary.effective_from <= latestStart) {
      nextErrors.effective_from = ['must be later than the latest salary record']
    }
    setErrors(nextErrors)
    return Object.keys(nextErrors).length === 0
  }

  function requestConfirmation(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setClientError('')
    setSuccessMessage('')
    if (employee?.status !== 'active') {
      setClientError('Only active employees can receive salary changes.')
      return
    }
    if (validateSalary()) setConfirmOpen(true)
  }

  async function submitSalaryChange() {
    setSubmitting(true)
    setErrors({})
    setClientError('')
    try {
      await apiRequest<{ salary_record: SalaryRecord }>(`/employees/${id}/salary_records`, {
        method: 'POST',
        body: { salary_record: salary },
      })
      setConfirmOpen(false)
      setSalary({ annual_salary: '', currency: '', effective_from: '' })
      setSuccessMessage('Salary change recorded.')
      setLoading(true)
      await load()
    } catch (cause) {
      setConfirmOpen(false)
      if (cause instanceof ApiError) setErrors(cause.errors)
      else setClientError('Unable to record the salary change. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) return <Box sx={{ minHeight: 240, display: 'grid', placeItems: 'center' }}><CircularProgress aria-label="Loading employee details" /></Box>
  if (loadError || !employee) return <Alert severity="error" role="alert">{loadError || 'Employee not found.'}</Alert>

  return (
    <Stack spacing={3}>
      <Stack direction={{ xs: 'column', sm: 'row' }} sx={{ justifyContent: 'space-between', alignItems: { sm: 'center' }, gap: 2 }}>
        <Box>
          <Typography variant="h4">{employee.name}</Typography>
          <Typography color="text.secondary">{employee.employee_number} · {employee.email}</Typography>
          <Typography color="text.secondary">{employee.country_code} · {employee.department} · {employee.status}</Typography>
        </Box>
        <Button component={RouterLink} to={`/employees/${employee.id}/edit`} variant="outlined" startIcon={<EditOutlinedIcon />}>Edit employee</Button>
      </Stack>
      {successMessage && <Alert severity="success">{successMessage}</Alert>}
      {clientError && <Alert severity="error" role="alert">{clientError}</Alert>}
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>Salary history</Typography>
          {salaryRecords.length === 0 ? (
            <Typography color="text.secondary">No salary records have been recorded.</Typography>
          ) : (
            <TableContainer>
              <Table aria-label="Salary history">
                <TableHead><TableRow>
                  <TableCell>Annual salary</TableCell><TableCell>Currency</TableCell>
                  <TableCell>Effective from</TableCell><TableCell>Effective to</TableCell>
                </TableRow></TableHead>
                <TableBody>
                  {salaryRecords.map((record) => (
                    <TableRow key={`${record.effective_from}-${record.created_at}`}>
                      <TableCell>{formatMoney(record.annual_salary, record.currency)}</TableCell>
                      <TableCell>{record.currency}</TableCell>
                      <TableCell>{formatDate(record.effective_from)}</TableCell>
                      <TableCell>{record.effective_to ? formatDate(record.effective_to) : 'No scheduled end'}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </CardContent>
      </Card>
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>Record salary change</Typography>
          {employee.status !== 'active' ? (
            <Alert severity="info">Salary changes are available for active employees only.</Alert>
          ) : (
            <Stack component="form" spacing={2} onSubmit={requestConfirmation} noValidate>
              <FormErrors errors={errors} />
              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                <TextField
                  label="Annual salary"
                  inputMode="decimal"
                  value={salary.annual_salary}
                  onChange={(event) => updateSalary('annual_salary', event.target.value)}
                  error={Boolean(errors.annual_salary?.length)}
                  helperText={errors.annual_salary?.join(', ') ?? 'Enter a decimal amount; it is sent without floating-point conversion.'}
                  required
                />
                <TextField
                  label="Currency"
                  slotProps={{ htmlInput: { maxLength: 3 } }}
                  value={salary.currency}
                  onChange={(event) => updateSalary('currency', event.target.value.toUpperCase())}
                  error={Boolean(errors.currency?.length)}
                  helperText={errors.currency?.join(', ')}
                  required
                />
                <TextField
                  label="Effective from"
                  type="date"
                  value={salary.effective_from}
                  onChange={(event) => updateSalary('effective_from', event.target.value)}
                  error={Boolean(errors.effective_from?.length)}
                  helperText={errors.effective_from?.join(', ') ?? 'Today or a future date, after the latest record.'}
                  slotProps={{ inputLabel: { shrink: true }, htmlInput: { min: kolkataToday() } }}
                  required
                />
              </Stack>
              <Box>
                <Button type="submit" variant="contained">Review salary change</Button>
              </Box>
            </Stack>
          )}
        </CardContent>
      </Card>
      <Dialog open={confirmOpen} onClose={() => !submitting && setConfirmOpen(false)} aria-labelledby="confirm-salary-title">
        <DialogTitle id="confirm-salary-title">Confirm salary change</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Record {formatMoney(salary.annual_salary || '0', salary.currency || '')} for {employee.name}, effective {formatDate(salary.effective_from)}?
            {latestStart && ` The current open salary period will end on ${formatDate(salary.effective_from)}.`}
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmOpen(false)} disabled={submitting}>Cancel</Button>
          <Button onClick={submitSalaryChange} variant="contained" disabled={submitting}>
            {submitting ? 'Recording…' : 'Confirm change'}
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  )
}
