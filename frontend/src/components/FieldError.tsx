import { Alert } from '@mui/material'
import type { FieldErrors } from '../api/client'

export function FormErrors({ errors }: { errors: FieldErrors }) {
  const messages = Object.entries(errors).flatMap(([field, fieldMessages]) =>
    fieldMessages.map((message) => `${field === 'base' ? '' : `${field.replaceAll('_', ' ')}: `}${message}`),
  )
  if (!messages.length) return null
  return <Alert severity="error">{messages.join(' · ')}</Alert>
}
