#!/usr/bin/env bash
set -euo pipefail

crew="${1:-xenota}"

exec gt polecat list "$crew"
