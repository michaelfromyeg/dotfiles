import { expect, test } from 'claude-code/testing'
import { annotateUtcTimes } from './annotate'

const LA = 'America/Los_Angeles'
const NOV_19 = new Date('2026-11-19T20:00:00Z')
const JUL_1 = new Date('2026-07-01T20:00:00Z')

test('ISO datetime with Z gets local time appended', () => {
  expect(annotateUtcTimes('Deployed at 2026-11-19T18:04:00Z.', LA, NOV_19)).toBe(
    'Deployed at 2026-11-19T18:04:00Z (10:04:00 AM PST).',
  )
})

test('ISO datetime with +00:00 and no seconds', () => {
  expect(annotateUtcTimes('at 2026-11-19T18:04+00:00', LA, NOV_19)).toBe(
    'at 2026-11-19T18:04+00:00 (10:04 AM PST)',
  )
})

test('space-separated datetime with UTC suffix', () => {
  expect(annotateUtcTimes('2026-11-19 18:04 UTC', LA, NOV_19)).toBe('2026-11-19 18:04 UTC (10:04 AM PST)')
})

test('datetime that lands on a different local day shows the local date', () => {
  expect(annotateUtcTimes('2026-11-19T03:00:00Z', LA, NOV_19)).toBe(
    '2026-11-19T03:00:00Z (Nov 18 at 7:00:00 PM PST)',
  )
})

test('summer datetime uses daylight time', () => {
  expect(annotateUtcTimes('2026-07-01T18:04Z', LA, JUL_1)).toBe('2026-07-01T18:04Z (11:04 AM PDT)')
})

test('clock time with UTC uses today for DST', () => {
  expect(annotateUtcTimes('The job runs at 18:04 UTC.', LA, JUL_1)).toBe(
    'The job runs at 18:04 UTC (11:04 AM PDT).',
  )
})

test('clock time that crosses midnight says previous day', () => {
  expect(annotateUtcTimes('03:00 UTC', LA, NOV_19)).toBe('03:00 UTC (7:00 PM PST, previous day)')
})

test('12-hour time with UTC', () => {
  expect(annotateUtcTimes('around 6:30 PM UTC', LA, NOV_19)).toBe('around 6:30 PM UTC (10:30 AM PST)')
})

test('hour-only 12-hour time with UTC', () => {
  expect(annotateUtcTimes('by 6pm UTC', LA, NOV_19)).toBe('by 6pm UTC (10:00 AM PST)')
})

test('unzoned times are left alone', () => {
  expect(annotateUtcTimes('at 2026-11-19 18:04:00 and 18:04', LA, NOV_19)).toBe(
    'at 2026-11-19 18:04:00 and 18:04',
  )
})

test('fenced and inline code are left alone', () => {
  const text = 'Run `since 2026-11-19T18:04Z` then:\n```\nts=18:04 UTC\n```\nDone at 19:00 UTC.'
  expect(annotateUtcTimes(text, LA, NOV_19)).toBe(
    'Run `since 2026-11-19T18:04Z` then:\n```\nts=18:04 UTC\n```\nDone at 19:00 UTC (11:00 AM PST).',
  )
})

test('an unclosed fence while streaming is left alone', () => {
  expect(annotateUtcTimes('Log:\n```\n18:04 UTC', LA, NOV_19)).toBe('Log:\n```\n18:04 UTC')
})

test('a UTC zone setting leaves text unchanged', () => {
  expect(annotateUtcTimes('18:04 UTC', 'Etc/UTC', NOV_19)).toBe('18:04 UTC')
})

test('words that start with UTC or GMT are not a mark', () => {
  expect(annotateUtcTimes('18:04 GMTX', LA, NOV_19)).toBe('18:04 GMTX')
})

test('a zone whose short name contains GMT is not annotated twice', () => {
  expect(annotateUtcTimes('18:04 UTC', 'Asia/Tokyo', NOV_19)).toBe('18:04 UTC (3:04 AM GMT+9, next day)')
})

test('a GMT offset other than zero is not read as UTC', () => {
  expect(annotateUtcTimes('18:04 GMT+9', LA, NOV_19)).toBe('18:04 GMT+9')
})
