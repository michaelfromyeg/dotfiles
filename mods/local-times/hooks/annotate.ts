// Only times that say they are UTC are annotated; an unzoned time may already be local.
// One pattern scans the original text once, so an appended annotation (which may read
// "3:04 AM GMT+9") is never scanned again. Alternatives, in order: an ISO datetime, a clock
// time, an hour with AM/PM.
const UTC_MARK = String.raw`(?:Z|[+-]00:?00|\s?(?:UTC|GMT)(?![A-Za-z+-]))`
const MERIDIEM = String.raw`\s?([AaPp])\.?[Mm]\.?`
const UTC_TIME = new RegExp(
  [
    String.raw`\b(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?${UTC_MARK}`,
    String.raw`(?<![\d:.-])(\d{1,2}):(\d{2})(?::(\d{2}))?(?:${MERIDIEM})?${UTC_MARK}`,
    String.raw`(?<![\d:.-])(\d{1,2})${MERIDIEM}\s?(?:UTC|GMT)(?![A-Za-z+-])`,
  ].join('|'),
  'g',
)

// Fenced blocks (closed or still streaming) and inline code are left verbatim so copied values stay exact.
const CODE_SPANS = /(```[\s\S]*?(?:```|$)|`[^`\n]*`)/

export function annotateUtcTimes(text: string, timeZone: string, now: Date = new Date()): string {
  if (isUtc(timeZone)) {
    return text
  }

  return text
    .split(CODE_SPANS)
    .map((part, i) => (i % 2 === 1 ? part : annotateProse(part, timeZone, now)))
    .join('')
}

export function systemTimeZone(): string {
  return new Intl.DateTimeFormat().resolvedOptions().timeZone
}

function annotateProse(prose: string, timeZone: string, now: Date): string {
  return prose.replace(UTC_TIME, (match, ...g: (string | undefined)[]) => {
    const [y, mo, d, isoH, isoMi, isoS, clockH, clockMi, clockS, clockAmPm, hourH, hourAmPm] = g
    const local = y
      ? formatIsoDatetime(+y!, +mo!, +d!, +isoH!, +isoMi!, isoS, timeZone)
      : clockH
        ? formatClock(+clockH, +clockMi!, clockS, clockAmPm, timeZone, now)
        : formatClock(+hourH!, 0, undefined, hourAmPm, timeZone, now)

    return local ? `${match} (${local})` : match
  })
}

function formatIsoDatetime(
  y: number,
  mo: number,
  d: number,
  h: number,
  mi: number,
  s: string | undefined,
  timeZone: string,
): string | undefined {
  if (h > 23 || mi > 59) {
    return undefined
  }
  const instant = new Date(Date.UTC(y, mo - 1, d, h, mi, s ? +s : 0))
  const utcDateKey = instant.toISOString().slice(0, 10)
  return formatLocal(instant, timeZone, {
    withSeconds: s !== undefined,
    withDate: localDateKey(instant, timeZone) !== utcDateKey,
  })
}

function formatClock(
  h: number,
  mi: number,
  s: string | undefined,
  meridiem: string | undefined,
  timeZone: string,
  now: Date,
): string | undefined {
  const hour = to24Hour(h, meridiem)
  if (hour === undefined || mi > 59) {
    return undefined
  }
  return formatClockTime(hour, mi, s === undefined ? undefined : +s, timeZone, now)
}

function to24Hour(hour: number, meridiem: string | undefined): number | undefined {
  if (!meridiem) {
    return hour <= 23 ? hour : undefined
  }
  if (hour < 1 || hour > 12) {
    return undefined
  }
  const isPm = meridiem.toLowerCase() === 'p'
  return (hour % 12) + (isPm ? 12 : 0)
}

// A bare clock time carries no date, so it is read as that time on today's UTC date: DST is
// then right for the current day, and a shift across midnight is called out instead of a date.
function formatClockTime(
  hour: number,
  minute: number,
  second: number | undefined,
  timeZone: string,
  now: Date,
): string {
  const instant = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), hour, minute, second ?? 0),
  )
  // YYYY-MM-DD keys compare correctly as strings.
  const localDay = localDateKey(instant, timeZone)
  const utcDay = instant.toISOString().slice(0, 10)
  const local = formatLocal(instant, timeZone, { withSeconds: second !== undefined, withDate: false })

  if (localDay < utcDay) {
    return `${local}, previous day`
  }
  if (localDay > utcDay) {
    return `${local}, next day`
  }
  return local
}

function formatLocal(
  instant: Date,
  timeZone: string,
  { withSeconds, withDate }: { withSeconds: boolean; withDate: boolean },
): string {
  return new Intl.DateTimeFormat('en-US', {
    timeZone,
    month: withDate ? 'short' : undefined,
    day: withDate ? 'numeric' : undefined,
    hour: 'numeric',
    minute: '2-digit',
    second: withSeconds ? '2-digit' : undefined,
    timeZoneName: 'short',
  }).format(instant)
}

function localDateKey(instant: Date, timeZone: string): string {
  // en-CA formats dates as YYYY-MM-DD.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(instant)
}

function isUtc(timeZone: string): boolean {
  return ['UTC', 'Etc/UTC', 'Etc/GMT', 'GMT', 'Etc/Universal', 'Etc/Zulu'].includes(timeZone)
}
