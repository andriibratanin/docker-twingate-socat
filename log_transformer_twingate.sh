#!/usr/bin/env bash
#
# Read log lines from stdin, reformat them into:
# [YYYY-MM-DDThh:mm:ss.000000+0000] [INFO] [twingate] message
# Example:
# - input (raw)      : message
# - output (twingate): [2026-01-25T15:57:35.112927+0000] [INFO] [twingate] message

while IFS= read -r msg; do
    # Skip empty lines
    [[ -z "$msg" ]] && continue

    # Get current timestamp in ISO8601 with microseconds +0000
    # Linux date supports %N for nanoseconds; we cut to 6 digits
    ts=$(date -u +"%Y-%m-%dT%H:%M:%S.%6N+0000")

    # Use INFO level
    level="INFO"

    # Print formatted
    printf "[%s] [%s] [twingate] %s\n" "$ts" "$level" "$msg"
done
