#!/usr/bin/env bash
#
# Read log lines from stdin, reformat them into:
# [YYYY-MM-DDThh:mm:ss.000000+0000] [LEVEL] program message
# Example:
# - input (socat)    : 2026/01/25 15:57:39 socat[71] W message
# - output (twingate): [2026-01-25T15:57:35.112927+0000] [WARNING] [socat[71]] message

while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Break input line into fields
    # Input: YYYY/MM/DD hh:mm:ss program LEVEL message...
    ts_date=$(echo "$line" | awk '{print $1}')
    ts_time=$(echo "$line" | awk '{print $2}')
    prog=$(echo "$line" | awk '{print $3}')
    level=$(echo "$line" | awk '{print $4}')
    msg=$(echo "$line" | cut -d' ' -f5-)

    # Convert timestamp to ISO8601 with fixed fractional and +0000
    iso_date=${ts_date//\//-} # YYYY-MM-DD
    #iso_ts="${iso_date}T${ts_time}.000000+0000" - if socat is running without "-lu" option
    iso_ts="${iso_date}T${ts_time}+0000"

    # Expand level codes
    case "$level" in
        E|e) full="ERROR" ;;
        W|w) full="WARNING" ;;
        I|i) full="INFO" ;;
        D|d) full="DEBUG" ;;
        *)   full="$level" ;;  # leave as-is if unknown
    esac

    # Print formatted
    printf "[%s] [%s] %s %s\n" "$iso_ts" "$full" "[$prog]" "$msg"
done
