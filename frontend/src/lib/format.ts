export function formatDate(value: string | null) {
  if (!value) return 'Open-ended'
  const date = new Date(`${value.slice(0, 10)}T12:00:00`)
  return new Intl.DateTimeFormat('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(date)
}

export function formatMoney(amount: string, currency: string) {
  const [whole, fraction] = amount.split('.')
  const grouped = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(BigInt(whole))
  return `${currency} ${grouped}${fraction ? `.${fraction}` : ''}`
}

export function kolkataToday() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date())
  const value = (type: Intl.DateTimeFormatPartTypes) => parts.find((part) => part.type === type)?.value ?? ''
  return `${value('year')}-${value('month')}-${value('day')}`
}

export function isValidIsoDate(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false
  const date = new Date(`${value}T00:00:00Z`)
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value
}

export function dateDaysBefore(date: string, days: number) {
  const day = new Date(`${date}T12:00:00Z`)
  day.setUTCDate(day.getUTCDate() - days)
  return day.toISOString().slice(0, 10)
}
