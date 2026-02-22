# Xenota Monorepo

Combined workspace for Xenota Collective projects.

## Submodules

- **handbook/** - Xenota Collective handbook and documentation
- **xenon/** - Anthropic's Xenon project

## Setup

```bash
git clone --recurse-submodules git@github.com:xenota-collective/xenota.git
```

Or if already cloned:
```bash
git submodule update --init --recursive
```

## Bead Labels

Component labels for organizing work:

| Label | Scope |
|---|---|
| `nucleus` | Core cognitive loop, ticks, OODA, dispatches |
| `repertoire` | Routine runtime library (xr) |
| `repertoire-studio` | Repertoire dev tools (xrs) |
| `xenon-cli` | Go CLI for instance lifecycle (init/up/down) |
| `projection` | projection-cli, chat-server, chat-projection container |
| `vps-control` | SSH/SCP and container control library |
| `handbook` | Documentation site, manifesto, specs |
| `infra` | dev-vps, projection-base containers, build scripts |
