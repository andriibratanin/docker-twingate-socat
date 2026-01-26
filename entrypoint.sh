#!/bin/bash

pid_twingate=0
pid_port_forwarder=0

# Termination handler
term_handler() {
  if [[ "$pid_twingate" -ne 0 ]]; then
    kill -SIGTERM "$pid_twingate"
    wait "$pid_twingate"
  fi

  if [[ "$pid_port_forwarder" -ne 0 ]]; then
    # Kill all Port Forwarder processes
    killall -SIGTERM socat
    wait "$pid_port_forwarder"
  fi

  exit 143;
}

trap 'kill ${!}; term_handler' TERM

# Log single and multiple lines
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp

    # Loop over each line in the message
    while IFS= read -r line; do
        #timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        timestamp=$(date +"%Y-%m-%dT%H:%M:%S.%6N%z")

        echo "[$timestamp] [$level] [entrypoint.sh] $line"
    done <<< "$message"
}

# Try to get a Service Key from a file
if [[ -n "$SERVICE_KEY_PATH" ]]; then
    if [[ -f "$SERVICE_KEY_PATH" ]]; then
        SERVICE_KEY=$(cat "$SERVICE_KEY_PATH")
    else
        log "ERROR" "Service Key file '$SERVICE_KEY_PATH' not found, exit..."
        exit 1
    fi
fi

# Validate the Service Key
if [[ -z "$SERVICE_KEY" ]]; then
    log "ERROR" "No Service Key found, exit..."
    exit 1
fi

# Port Forwarder
log "INFO" "Starting Port Forwarder"

if [[ -z "$PORT_MAPPINGS" ]]; then
    log "ERROR" "PORT_MAPPINGS is not set"
    log "INFO" "Usage:"
    log "INFO" "Define PORT_MAPPINGS environment variable in format: 'LOCAL_PORT1:REMOTE_HOST1:REMOTE_PORT1;LOCAL_PORT2:REMOTE_HOST2:REMOTE_PORT2...'"
    log "INFO" "Example:"
    log "INFO" "export PORT_MAPPINGS='80:sensors.raspberrypi.private:80;81:smarthome.raspberrypi.private:81'"
    log "INFO" "Only TCP connections are supported"
    exit 1
fi

# Parse port mappings split by ';' and start Port Forwarder
IFS=';' read -r -a mappings <<< "$PORT_MAPPINGS"
for map in "${mappings[@]}"; do
    # Skip empty entries
    [[ -z "$map" ]] && continue

    # Expect exactly 3 parts: local:host:port
    IFS=':' read -r local_port remote_host remote_port <<< "$map"

    # Acceptable edge cases
    if [[ -n "$local_port" && -z "$remote_host" && -z "$remote_port" ]]; then
        # only host was specified - assuming both local and remote ports are 80
        remote_host=$local_port
        local_port=80
        remote_port=80
    elif [[ -n "$local_port" && -n "$remote_host" && -z "$remote_port" ]]; then
        # local port and remote host were specified - assuming remote port is 80
        remote_port=80
    elif [[ -z "$local_port" && -z "$remote_host" && -z "$remote_port" ]]; then
        # skip empty mappings
        continue
    fi

    # Start Port Forwarder (Socat)
    log "INFO" "Forwarding 0.0.0.0:${local_port} -> ${remote_host}:${remote_port}"

    # Socat without logs transformation
    #socat TCP4-LISTEN:"$local_port",bind=0.0.0.0,fork,reuseaddr TCP4:"$remote_host":"$remote_port" >/proc/1/fd/1 2>&1 &
    # Socat with logs transformation into Twingate format
    socat -lu -d TCP4-LISTEN:"$local_port",bind=0.0.0.0,fork,reuseaddr TCP4:"$remote_host":"$remote_port" 2>&1 \
        | bash /log_transformer_socat.sh >/proc/1/fd/1 &

    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to start Port Forwarder for mapping: $map"
        continue
    fi

    # Get PID of the first Port Forwarder
    if [[ "$pid_port_forwarder" -eq 0 ]]; then
        pid_port_forwarder="${!}"
    fi
done

if [[ "$pid_port_forwarder" -eq 0 ]]; then
    log "ERROR" "No Port Forwarder is running - nothing to do, exiting"
    exit 1
fi

# let Port Forwarder initialization to finish (prevent mixing Port Forwarder and Twingate logs)
sleep 1

# Twingate configuration
log "INFO" "Configuring Twingate"
echo "$SERVICE_KEY" \
    | twingate setup --headless=- \
    | bash /log_transformer_twingate.sh >/proc/1/fd/1 &

# Twingate operation
log "INFO" "Starting Twingate"
twingate_log=/var/log/twingated.log
if [[ ! -f "$twingate_log" ]]; then
    touch "$twingate_log"
fi
if [[ -n "$LOG_TWINGATE_TRUNCATE" && -n "$LOG_TWINGATE" ]]; then
    log "WARNING" "Truncating log '$twingate_log'"
    echo -n "" > $twingate_log
else
    log "INFO" "Set 'LOG_TWINGATE_TRUNCATE=1' to truncate Twingate log before start (requires 'LOG_TWINGATE' to be set as well)"
fi

#twingate start >/dev/null 2>&1 & - this will not work (logs will still be printed - use "&>/dev/null" instead)
twingate start --disable-colors \
    | bash /log_transformer_twingate.sh >/proc/1/fd/1 &
pid_twingate="${!}"

if [[ ! -z "$LOG_TWINGATE" ]]; then
    log "WARNING" "Redirecting Twingate log to container log"
    tail -f -n1000 $twingate_log >/proc/1/fd/1 2>&1 &
else
    log "INFO" "Set 'LOG_TWINGATE=1' to redirect Twingate log to container log"
fi

if [[ -z "$LOG_RESOURCES" ]]; then
    log "INFO" "Set 'LOG_RESOURCES=1' to log available Twingate resources"
fi

sleep 3s

old_status="unknown"
old_resources="unknown"
while :; do
    TWINGATE_STATUS=$(twingate status)
    if [[ "$old_status" != "$TWINGATE_STATUS" ]]; then
        #if [[ "$TWINGATE_STATUS" != 'online' ]]; then
            log "WARNING" "Twingate status: $TWINGATE_STATUS"
        #else
        #    log "INFO" "Twingate status: $TWINGATE_STATUS"
        #fi
    fi
    old_status=$TWINGATE_STATUS

    if [[ "$TWINGATE_STATUS" != 'online' ]]; then
        # Offline

        # do nothing (passively wait for Twingate to restore connectivity):
        :

        # OR exit the container:
        #log "ERROR" "Twingate is offline - exiting"
        #exit 1

        # OR restart Twingate:
        #log "WARNING" "Twingate is offline - restarting it"
        #kill $pid_twingate
        #twingate start \
        #    | bash /log_transformer_twingate.sh >/proc/1/fd/1 &
        #pid_twingate="${!}"
    else
        # Online
        if [[ ! -z "$LOG_RESOURCES" ]]; then
            TWINGATE_RESOURCES=$(twingate resources)
            if [[ "$old_resources" != "$TWINGATE_RESOURCES" ]]; then
                log "INFO" "Twingate resources:"
                log "INFO" "$TWINGATE_RESOURCES"
            fi
            old_resources=$TWINGATE_RESOURCES
        fi
    fi

    sleep 30
done
