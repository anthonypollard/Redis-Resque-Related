#!/bin/bash

BATCH_SIZE=100
PATTERN="resque:status:*"
TOTAL_PROCESSED=0
TOTAL_DELETED=0
CURSOR=0
DB_TO_USE="db0"

# Function to run a Redis command with retry logic
run_redis_cmd() {
    local cmd="$1"
    local result
    local attempts=0
    while :; do
        result=$(eval "$cmd")
        if [[ "$result" == *"Could not connect to Redis"* ]]; then
            echo "Redis connection failed. Retrying in 3 seconds..."
            sleep 3
            ((attempts++))
            if [ $attempts -ge 5 ]; then
                echo "Failed to connect to Redis after multiple attempts. Waiting for 60 minutes before retrying..."
                sleep 3600
                attempts=0
            fi
        else
            echo "$result"
            return 0
        fi
    done
}

while :; do
    KEY_SPACE=$(run_redis_cmd "/usr/bin/redis-cli INFO keyspace | grep '$DB_TO_USE:' | grep -oP '(?<=keys=)\d+'")
    STATUS_KEYS=$(run_redis_cmd "/usr/bin/redis-cli ZCARD resque:_statuses")
    SCAN_RESULT=$(run_redis_cmd "/usr/bin/redis-cli SCAN $CURSOR MATCH \"$PATTERN\" COUNT $BATCH_SIZE")
    CURSOR=$(echo "$SCAN_RESULT" | head -n 1)
    KEYS=$(echo "$SCAN_RESULT" | tail -n +2)

    if [ -z "$KEYS" ]; then
        echo "No keys found in this batch. Continuing scan..."
    else
        echo "[Keyspace: $KEY_SPACE] [Status Keys: $STATUS_KEYS] [Total Processed: $TOTAL_PROCESSED] [Deleted: $TOTAL_DELETED]"
        COUNT=0
        DELETES=0

        for KEY in $KEYS; do
            tput cup 0 0
            sleep 0.02 #tiny delay to limit redis commands per loop to 150/sec or less
            STATUS=$(run_redis_cmd "/usr/bin/redis-cli GETRANGE \"$KEY\" 0 2999")

            if [[ "$STATUS" == *"\"status\":\"completed\""* ]]; then
                # Slice out the UUID
                UUID=${KEY#resque:status:}

                # Delete key from resque:status
                run_redis_cmd "/usr/bin/redis-cli DEL \"$KEY\" > /dev/null"

                # Del key using UUID from the resque:_statuses set, this is the set seen on the webui
                run_redis_cmd "/usr/bin/redis-cli ZREM resque:_statuses \"$UUID\" > /dev/null"

                ((DELETES++))
            fi

            ((COUNT++))
        done

        TOTAL_PROCESSED=$((TOTAL_PROCESSED + COUNT))
        TOTAL_DELETED=$((TOTAL_DELETED + DELETES))
    fi

    sleep 0.05 #Tiny delay to prevent overuse of CPU for underpowered machines and ulimit sessions
    clear
    if [ "$CURSOR" -eq 0 ]; then
        break
    fi
done

echo "Script Complete, $TOTAL_PROCESSED keys processed, $TOTAL_DELETED keys deleted. New Keyspace: $KEY_SPACE, New StatusKeys: $STATUS_KEYS"
