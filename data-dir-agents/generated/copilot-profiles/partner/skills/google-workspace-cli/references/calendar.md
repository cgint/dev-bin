# Google Calendar CLI Reference (`gws calendar`)

Operational patterns, query traps, and recipes for interacting with Google Calendar via `gws`.

## Critical query rules & traps

### 1. Recurring events expansion (`singleEvents`)
When listing events across a specific time interval (e.g. a day or week agenda), you **must** pass:
```json
{
  "singleEvents": true,
  "orderBy": "startTime"
}
```
- **Why**: Without `"singleEvents": true`, recurring events only exist at their original series creation timestamp. They will **not** appear within subsequent date ranges unless expanded into individual instances.
- Note: Google Calendar API requires `orderBy="startTime"` whenever `singleEvents=true`.

### 2. Calendar scope (`calendarId`)
- **Default personal calendar**: Explicitly pass `"calendarId": "primary"` (or `--calendar primary` depending on command style).
- **The `+agenda` shortcut caution**: `gws calendar +agenda` queries across all subscribed calendars by default (including meeting rooms, team schedules, and colleague calendars). Do not rely on `+agenda` when calculating personal free/busy times or checking personal conflicts; target `"primary"` explicitly.

### 3. Timestamp formatting
- Timestamps for `timeMin` and `timeMax` must be RFC3339 formatted strings with timezone offsets (e.g. `2026-04-07T00:00:00Z` or `2026-04-07T00:00:00+02:00`).

---

## Read recipes

### Daily agenda for primary calendar

Query events for a single target day:
```bash
gws calendar events list --params '{
  "calendarId": "primary",
  "timeMin": "2026-04-07T00:00:00Z",
  "timeMax": "2026-04-07T23:59:59Z",
  "singleEvents": true,
  "orderBy": "startTime"
}'
```

### Overlap & conflict detection (Free/Busy query)

To check availability without downloading individual event details, use the `freebusy` endpoint:
```bash
gws calendar freebusy query --json '{
  "timeMin": "2026-04-07T08:00:00Z",
  "timeMax": "2026-04-07T18:00:00Z",
  "items": [{"id": "primary"}]
}'
```

Alternatively, iterate over `events.list` items where `singleEvents: true`, filtering for items with `start.dateTime` and `end.dateTime` overlapping candidate intervals.

---

## Write recipes (Requires explicit user confirmation)

Modifying calendars triggers external notifications and alters user schedules. Always verify method parameters with `gws schema calendar.events.insert` and confirm event details with the user before executing.

### Create an event with Google Meet link

```bash
gws calendar events insert --params '{"calendarId": "primary", "conferenceDataVersion": 1}' --json '{
  "summary": "Project Sync",
  "description": "Weekly alignment discussion",
  "start": { "dateTime": "2026-04-07T14:00:00+02:00" },
  "end": { "dateTime": "2026-04-07T14:30:00+02:00" },
  "conferenceData": {
    "createRequest": {
      "requestId": "unique-request-id-12345",
      "conferenceSolutionKey": { "type": "hangoutsMeet" }
    }
  }
}'
```
