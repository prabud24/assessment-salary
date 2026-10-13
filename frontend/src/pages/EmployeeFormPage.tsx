import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { Alert, Box, Button, Card, CardContent, CircularProgress, MenuItem, Stack, TextField, Typography } from '@mui/material'
import { Link as RouterLink, useNavigate, useParams } from 'react-router-dom'
import { ApiError, apiRequest } from '../api/client'
import type { Employee, EmployeeAttributes, FieldErrors } from '../api/client'
import { FormErrors } from '../components/FieldError'

const emptyEmployee: EmployeeAttributes = {
  employee_number: '',
  name: '',
  email: '',
  country_code: '',
  department: '',
  status: 'active',
}

const fields: { name: keyof EmployeeAttributes; label: string; autoComplete?: string }[] = [
  { name: 'employee_number', label: 'Employee number' },
  { name: 'name', label: 'Name', autoComplete: 'name' },
  { name: 'email', label: 'Email', autoComplete: 'email' },
  { name: 'country_code', label: 'Country code' },
  { name: 'department', label: 'Department' },
]

export function EmployeeFormPage() {
  const { id } = useParams()
  const editing = Boolean(id)
  const navigate = useNavigate()
  const [values, setValues] = useState<EmployeeAttributes>(emptyEmployee)
  const [errors, setErrors] = useState<FieldErrors>({})
  const [loading, setLoading] = useState(editing)
  const [submitting, setSubmitting] = useState(false)
  const [loadError, setLoadError] = useState('')

  useEffect(() => {
    if (!id) return
    let current = true
    apiRequest<{ employee: Employee }>(`/employees/${id}`)
      .then(({ employee }) => {
        if (!current) return
        const { employee_number, name, email, country_code, department, status } = employee
        setValues({ employee_number, name, email, country_code, department, status })
      })
      .catch((cause: unknown) => {
        if (current) setLoadError(cause instanceof Error ? cause.message : 'Unable to load employee.')
      })
      .finally(() => { if (current) setLoading(false) })
    return () => { current = false }
  }, [id])

  function setField<K extends keyof EmployeeAttributes>(field: K, value: EmployeeAttributes[K]) {
    setValues((previous) => ({ ...previous, [field]: value }))
    setErrors((previous) => ({ ...previous, [field]: [] }))
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setErrors({})
    setSubmitting(true)
    try {
      const response = await apiRequest<{ employee: Employee }>(editing ? `/employees/${id}` : '/employees', {
        method: editing ? 'PATCH' : 'POST',
        body: { employee: values },
      })
      navigate(`/employees/${response.employee.id}`, { replace: true })
    } catch (cause) {
      if (cause instanceof ApiError) setErrors(cause.errors)
      else setErrors({ base: ['Unable to save employee. Please try again.'] })
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) return <Box sx={{ minHeight: 240, display: 'grid', placeItems: 'center' }}><CircularProgress aria-label="Loading employee" /></Box>
  if (loadError) return <Alert severity="error" role="alert">{loadError}</Alert>

  return (
    <Stack spacing={3} sx={{ maxWidth: 760, mx: 'auto' }}>
      <Box>
        <Typography variant="h4">{editing ? 'Edit employee' : 'Add employee'}</Typography>
        <Typography color="text.secondary">Employee details are validated by the HR system.</Typography>
      </Box>
      <Card>
        <CardContent sx={{ p: { xs: 2, sm: 4 } }}>
          <Stack component="form" spacing={2.5} onSubmit={submit} noValidate>
            <FormErrors errors={errors} />
            <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 2 }}>
              {fields.map((field) => (
                <TextField
                  key={field.name}
                  label={field.label}
                  autoComplete={field.autoComplete}
                  value={values[field.name]}
                  onChange={(event) => setField(field.name, event.target.value)}
                  error={Boolean(errors[field.name]?.length)}
                  helperText={errors[field.name]?.join(', ')}
                  required
                  fullWidth
                />
              ))}
              <TextField
                select
                label="Employment status"
                value={values.status}
                onChange={(event) => setField('status', event.target.value as EmployeeAttributes['status'])}
                error={Boolean(errors.status?.length)}
                helperText={errors.status?.join(', ')}
                required
              >
                <MenuItem value="active">Active</MenuItem>
                <MenuItem value="inactive">Inactive</MenuItem>
              </TextField>
            </Box>
            <Stack direction="row" spacing={1.5} sx={{ justifyContent: 'flex-end' }}>
              <Button component={RouterLink} to={editing ? `/employees/${id}` : '/employees'}>Cancel</Button>
              <Button type="submit" variant="contained" disabled={submitting}>
                {submitting ? 'Saving…' : editing ? 'Save changes' : 'Create employee'}
              </Button>
            </Stack>
          </Stack>
        </CardContent>
      </Card>
    </Stack>
  )
}
