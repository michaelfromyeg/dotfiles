# local-times

A Claude Code mod that adds your local time after every UTC time in Claude's replies, so `Deployed at 2026-11-19T18:04:00Z` is drawn as `Deployed at 2026-11-19T18:04:00Z (10:04:00 AM PST)`.

It changes only what is drawn. The stored transcript, and what Claude reads back on later turns, stay in UTC, so Claude never mistakes a local time for UTC.

## What it converts

- ISO datetimes marked UTC: `2026-11-19T18:04Z`, `2026-11-19T18:04:00+00:00`, `2026-11-19 18:04 UTC`. When the local date differs, it is included: `(Nov 18 at 7:00 PM PST)`.
- Clock times marked UTC: `18:04 UTC`, `6:30 PM UTC`, `6pm GMT`. They are read as that time on today's UTC date, which gets daylight saving right for today, and a shift across midnight reads `(7:00 PM PST, previous day)`.

It leaves alone times with no zone (they may already be local), non-zero offsets such as `GMT+9`, fenced code blocks and inline code, so a value copied into a query or command stays exact.

## Install

At the prompt of a Claude Code terminal session:

```
/plugin install local-times --marketplace michaelfromyeg/dotfiles
```

From a shell:

```bash
claude plugin install local-times --marketplace michaelfromyeg/dotfiles
```

In the desktop app: click + next to the prompt box, then Plugins, Add marketplace with `michaelfromyeg/dotfiles`, then Add plugin.

## Configuration

The mod uses your computer's time zone. To use another, set its `timeZone` option in `/config` to an IANA zone such as `America/Vancouver`.

## Development

```bash
claude plugin validate mods/local-times
```

```bash
claude plugin test mods/local-times
```

`hooks/annotate.ts` holds the matching and formatting; `hooks/register.tsx` hooks the `AssistantMessage` render.
