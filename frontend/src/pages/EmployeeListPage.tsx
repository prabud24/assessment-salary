import { useEffect, useState } from 'react'
import type { ChangeEvent } from 'react'
import {
  Alert, Box, Button, Card, CardContent, CircularProgress, MenuItem, Stack, Table,
  TableBody, TableCell, TableContainer, TableHead, TableRow, TablePagination, TextField, Typography,
} from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import SearchIcon from '@mui/icons-material/Search'
import { Link as RouterLink } from 'react-router-dom'
import { apiRequest } from '../api/client'
import type { Employee, Pagination } from '../api/client'

type EmployeeListResponse = { employees: Employee[]; pagination: Pagination }

export function EmployeeListPage() {
  const [employees, setEmployees] = useState<Employee[]>([])
  const [pagination, setPagination] = useState<Pagination>({ page: 1, per_page: 25, total_count: 0, total_pages: 0 })
  const [q, setQ] = useState('')
  const [country, setCountry] = useState('')
  const [department, setDepartment] = useState('')
  const [status, setStatus] = useState('')
  const [page, setPage] = useState(0)
  const [perPage, setPerPage] = useState(25)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let current = true
    const params = new URLSearchParams({ page: String(page + 1), per_page: String(perPage) })
    if (q.trim()) params.set('q', q.trim())
    if (country.trim()) params.set('country', country.trim().toUpperCase())
    if (department.trim()) params.set('department', department.trim())
    if (status) params.set('status', status)
    apiRequest<EmployeeListResponse>(`/employees?${params}`)
      .then((result) => {
        if (current) {
          setEmployees(result.employees)
          setPagination(result.pagination)
        }
      })
      .catch((cause: unknown) => {
        if (current) {
          setError(cause instanceof Error ? cause.message : 'Unable to load employees.')
          setEmployees([])
          setPagination({ page: page + 1, per_page: perPage, total_count: 0, total_pages: 0 })
        }
      })
      .finally(() => {
        if (current) setLoading(false)
      })
    return () => { current = false }
  }, [q, country, department, status, page, perPage])

  function updateFilter(setter: (value: string) => void) {
    return (event: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
      setLoading(true)
      setError('')
      setter(event.target.value)
      setPage(0)
    }
  }

  return (
    <Stack spacing={3}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: { xs: 'stretch', sm: 'center' }, flexDirection: { xs: 'column', sm: 'row' }, gap: 2 }}>
        <Box>
          <Typography variant="h4">Employees</Typography>
          <Typography color="text.secondary">Search and manage employee records.</Typography>
        </Box>
        <Button component={RouterLink} to="/employees/new" variant="contained" startIcon={<AddIcon />}>Add employee</Button>
      </Box>
      <Card>
        <CardContent>
          <Stack direction={{ xs: 'column', md: 'row' }} spacing={2}>
            <TextField label="Search employees" placeholder="Number, name, or email" value={q} onChange={updateFilter(setQ)} slotProps={{ input: { startAdornment: <SearchIcon fontSize="small" sx={{ mr: 1, color: 'text.secondary' }} /> } }} />
            <TextField label="Country" placeholder="e.g. IN" value={country} onChange={updateFilter(setCountry)} />
            <TextField label="Department" value={department} onChange={updateFilter(setDepartment)} />
            <TextField select label="Status" value={status} onChange={(event) => { setLoading(true); setError(''); setStatus(event.target.value); setPage(0) }} sx={{ minWidth: 140 }}>
              <MenuItem value="">All statuses</MenuItem>
              <MenuItem value="active">Active</MenuItem>
              <MenuItem value="inactive">Inactive</MenuItem>
            </TextField>
          </Stack>
        </CardContent>
      </Card>
      {error && <Alert severity="error" role="alert">{error}</Alert>}
      <Card>
        {loading ? (
          <Box sx={{ minHeight: 220, display: 'grid', placeItems: 'center' }}><CircularProgress aria-label="Loading employees" /></Box>
        ) : error ? (
          <Box sx={{ minHeight: 220, display: 'grid', placeItems: 'center', p: 3 }}>
            <Typography color="text.secondary">The employee list is unavailable.</Typography>
          </Box>
        ) : employees.length === 0 ? (
          <Box sx={{ minHeight: 220, display: 'grid', placeItems: 'center', p: 3 }}>
            <Typography color="text.secondary">No employees match these filters.</Typography>
          </Box>
        ) : (
          <TableContainer>
            <Table aria-label="Employees">
              <TableHead><TableRow>
                <TableCell>Employee</TableCell><TableCell>Name</TableCell><TableCell>Email</TableCell>
                <TableCell>Country</TableCell><TableCell>Department</TableCell><TableCell>Status</TableCell>
              </TableRow></TableHead>
              <TableBody>
                {employees.map((employee) => (
                  <TableRow key={employee.id} hover>
                    <TableCell><Button component={RouterLink} to={`/employees/${employee.id}`} sx={{ p: 0, minWidth: 0 }}>{employee.employee_number}</Button></TableCell>
                    <TableCell>{employee.name}</TableCell><TableCell>{employee.email}</TableCell>
                    <TableCell>{employee.country_code}</TableCell><TableCell>{employee.department}</TableCell>
                    <TableCell sx={{ textTransform: 'capitalize' }}>{employee.status}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        )}
        <TablePagination
          component="div"
          count={pagination.total_count}
          page={page}
          onPageChange={(_, nextPage) => { setLoading(true); setError(''); setPage(nextPage) }}
          rowsPerPage={perPage}
          onRowsPerPageChange={(event) => { setLoading(true); setError(''); setPerPage(Number(event.target.value)); setPage(0) }}
          rowsPerPageOptions={[10, 25, 50, 100]}
          labelRowsPerPage="Rows per page"
        />
      </Card>
    </Stack>
  )
}
