# Manual Test Plan: xc-6g6w Chaperone Client

**Bead:** xc-6g6w (Tauri chaperone client: desktop app for xenon management)
**PR:** xenota-collective/xenota#25
**Date:** 2026-03-21
**Prerequisite:** A running nucleus with console API enabled on a known host:port.

---

## Prerequisites

- [ ] Nucleus running with console API on accessible host:port
- [ ] At least one projection configured (for projection/jobs/quarantine tests)
- [ ] API key available for each role: `observe`, `operate`, `override`
- [ ] Browser with devtools (for network/WebSocket inspection)

---

## MT-01: Connection & Session Handshake

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open app at `http://localhost:5176` | App shell renders with connection config inputs (Host, Port, Role) |
| 2 | Enter valid host, port, select `observe` role, click Connect | Status changes to "connected", session token stored in localStorage (`xenon.chaperone.session`) |
| 3 | Refresh browser page | Session restored from localStorage, no re-authentication prompt |
| 4 | Click Disconnect | Status returns to disconnected, localStorage cleared |
| 5 | Enter invalid host/port, click Connect | Error displayed with `network` category hint, status stays disconnected |
| 6 | Enter valid host but wrong API key | Error displayed with `auth` category hint (401) |

---

## MT-02: Role-Based Access Control

| Step | Action | Expected |
|------|--------|----------|
| 1 | Connect with `observe` role | All read tabs load data; mutation buttons (Start/Stop/Restart on projections, Cancel on jobs, Release/Dismiss on quarantine) are disabled |
| 2 | Connect with `operate` role | Mutation buttons enabled on projections (Start/Stop/Restart), jobs (Cancel), quarantine (Release/Dismiss) |
| 3 | Connect with `override` role | All `operate` buttons plus Revoke/Reactivate/Unrevoke on projections are enabled |

---

## MT-03: Navigation Tabs

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click each tab in order: Chat, Mind, Objectives, Dispatches, Strands, Projections, Journal, Jobs, Quarantine, Activity | Each tab activates and renders its panel without errors |
| 2 | Switch rapidly between tabs | No stale data, no blank panels, no console errors |

---

## MT-04: Chat (Conversation)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Navigate to Chat tab | Chat log area visible, input field at bottom |
| 2 | Type a message and submit | Message appears in chat log as chaperone bubble; SSE stream delivers xenon response that renders progressively |
| 3 | Send multiple messages in sequence | Conversation history maintained, auto-scroll follows new messages |
| 4 | Refresh page, return to Chat | Conversation history reloaded from `/api/v1/conversation/history` |

---

## MT-05: Awakening Flow

**Prerequisite:** Xenon in un-awakened state (or use a fresh nucleus).

| Step | Action | Expected |
|------|--------|----------|
| 1 | Connect to un-awakened xenon | Awakening modal appears automatically |
| 2 | Enter chaperone name, start awakening | SSE stream from `/api/v1/awaken` begins; phase indicator shows "Init" |
| 3 | Progress through each phase (Birthplace, Purpose, Naming, Avatar, Seeds, Invitation) | Phase indicator updates; chaperone input prompts appear when `awaiting_input` is true |
| 4 | Respond to each input prompt | Response sent via `/api/v1/awaken/respond`; conversation continues |
| 5 | Complete all phases | Celebration screen appears; xenon transitions to awakened state |
| 6 | Dismiss awakening view | Main app loads with full Chat tab |

---

## MT-06: Mind Panel

| Step | Action | Expected |
|------|--------|----------|
| 1 | Navigate to Mind tab | 8 sub-tabs visible for xenon state categories |
| 2 | Click through each sub-tab | Each renders JSON/structured data from `/api/v1/state/mind` |
| 3 | Verify genome data appears | Genome fields display with values (not null/empty) |

---

## MT-07: Projections

| Step | Action | Expected |
|------|--------|----------|
| 1 | Navigate to Projections tab | Grid of projection cards rendered |
| 2 | Verify each card shows: name, status badge, job count badge, quarantine count badge | Badges reflect actual counts from Jobs/Quarantine data |
| 3 | (operate role) Click Stop on a running projection | Projection status updates to stopped; card reflects new state |
| 4 | (operate role) Click Start on a stopped projection | Projection status updates to active |
| 5 | (operate role) Click Restart on a running projection | Projection cycles through stop→start; status returns to active |
| 6 | (override role) Click Revoke on an active projection | Projection enters revoked state |
| 7 | (override role) Click Unrevoke on a revoked projection | Projection returns to previous state |
| 8 | (override role) Click Reactivate on a suspended projection | Projection returns to active |
| 9 | Expand a projection card | Inline job list appears for that projection |
| 10 | Click raw config inspection | JSON config displayed correctly |

---

## MT-08: Journal & Drill-Down

| Step | Action | Expected |
|------|--------|----------|
| 1 | Navigate to Journal tab | Timeline of tick entries rendered |
| 2 | Verify each entry shows tick number and summary stats | Stats: dispatches received/actioned/deferred, strands created/completed, instructions emitted |
| 3 | Click on a tick entry | Detail panel loads from `/api/v1/state/journal/{tick}` |
| 4 | Verify drill-down content | JSON/structured tick state renders without errors |
| 5 | Click different ticks in sequence | Detail panel updates to selected tick |

---

## MT-09: Jobs

| Step | Action | Expected |
|------|--------|----------|
| 1 | Navigate to Jobs tab | Job cards grouped by status (running/pending/queued/completed/failed) |
| 2 | Verify each card shows: job ID, status, timestamps, associated projection | All fields populated from `/api/v1/state/jobs` |
| 3 | Verify failed jobs show error message | Error text visible on failed job cards |
| 4 | (operate role) Click Cancel on a running/pending job | Job transitions to cancelled state |

---

## MT-10: Quarantine

| Step | Action | Expected |
|------|--------|----------|
| 1 | Navigate to Quarantine tab | Quarantine entries rendered with pending count |
| 2 | Verify each entry shows: dispatch ID, reason, content, status, projection | Fields populated from `/api/v1/state/quarantine` |
| 3 | (operate role) Click Release on a pending entry | Entry transitions to released, dispatch proceeds |
| 4 | (operate role) Click Dismiss on a pending entry | Entry transitions to dismissed |
| 5 | (observe role) Verify Release/Dismiss buttons are disabled | Buttons present but non-interactive |

---

## MT-11: Dispatches

| Step | Action | Expected |
|------|--------|----------|
| 1 | Navigate to Dispatches tab | Dispatch cards rendered with priority indicators |
| 2 | Verify cards show: ID, priority, state, content preview | Color coding by state |
| 3 | Wait for new dispatch to arrive (or trigger externally) | New dispatch appears without manual refresh |

---

## MT-12: Strands (OODA Visualization)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Navigate to Strands tab | Strand cards rendered with OODA phase indicator |
| 2 | Verify each card shows: strand ID, current phase (Created → Orienting → Deciding → Acted) | Phase indicator highlights current step |
| 3 | (override role) Click Override on a strand in Deciding phase | Override dialog appears; enter decision + reasoning; strand updates |

---

## MT-13: Objectives

| Step | Action | Expected |
|------|--------|----------|
| 1 | Navigate to Objectives tab | Objective state and event history rendered |
| 2 | Verify objective events timeline | Events from `/api/v1/state/objective-events` displayed chronologically |

---

## MT-14: Activity (Live Stream)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Navigate to Activity tab | Live event stream from WebSocket renders |
| 2 | Open devtools Network tab, verify WS connection | WebSocket connected to `/api/v1/stream?session_token=...` |
| 3 | Trigger an action (e.g., start a projection) | Event appears in Activity stream in real-time |
| 4 | Kill nucleus briefly, then restart | WebSocket auto-reconnects with exponential backoff; events resume |

---

## MT-15: Error Handling

| Step | Action | Expected |
|------|--------|----------|
| 1 | Disconnect nucleus while app is connected | Network error displayed with retry hint; app does not crash |
| 2 | Let session token expire (wait for TTL) | Auto-renewal fires; if renewal fails, auth error displayed |
| 3 | Connect with expired/invalid token in localStorage | App detects invalid session, prompts re-authentication |

---

## MT-16: Tauri Desktop (if building desktop app)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `npm run tauri:dev` | Desktop window opens with full app |
| 2 | Repeat MT-01 through MT-15 in desktop window | All behaviors identical to browser |
| 3 | Close and reopen desktop app | Session restored from localStorage |

---

## Blockers (cannot test until API exists)

These Phase 4 features have no API backing and cannot be manually tested:

- **Container/resource monitoring** (xc-dw09.10.1) — no podman status endpoint
- **Settings panel** (xc-dw09.10.2) — no config read/write endpoint
- **Emergency shutdown** (xc-dw09.10.3) — no shutdown endpoint
- **Deploy from template** (xc-dw09.10.3) — no template deploy endpoint
- **Sovereignty controls** (xc-dw09.10.3) — no sovereignty endpoint
