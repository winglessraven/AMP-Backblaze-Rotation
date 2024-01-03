#!/bin/bash

# Backblaze B2 credentials
ACCOUNT_ID="" #keyID
APPLICATION_KEY="" #application key
MAX_FILES=7  # The maximum number of files you want to keep
LOG_FILE="/path/to/logfile.log"
BUCKET_IDS=("bucket1id" "bucket2id" "bucket3id") # List of bucket IDs
AMP_LOG_DIR="/home/amp/.ampdata/instances/" # Default AMP log directory
MODIFY_AMP_LOGS=false # Flag to modify AMP logs

# Check for --modify-amp-logs argument
if [[ "$1" == "--modify-amp-logs" ]]; then
    MODIFY_AMP_LOGS=true
fi

# Function to log messages
log_message() {
    echo "$(date): $1" | tee -a $LOG_FILE
}

# Function to process AMP logs
process_amp_logs() {
    local uuid=$1
    local found_files=$(find "$AMP_LOG_DIR" -name "Backups.json")

    log_message "Processing UUID: $uuid"

    for file in $found_files; do
        if grep -q "$uuid" "$file"; then
            log_message "Found UUID $uuid in file: $file"

            # Backup the original file
            cp "$file" "${file}.bak"

            # Set StoredRemotely to false for the given UUID
            modified=$(jq --arg uuid "$uuid" 'if (.[$uuid]?) then (.[$uuid].StoredRemotely) = false else . end' "$file")
            echo "$modified" > "$file"
            log_message "Set StoredRemotely to false for UUID $uuid in file: $file"

            # Remove entries where both StoredLocally and StoredRemotely are false
            modified=$(jq 'del(.[] | select(.StoredLocally == false and .StoredRemotely == false))' "$file")
            echo "$modified" > "$file"
            log_message "Removed entries with both StoredLocally and StoredRemotely set to false in file: $file"
        else
            log_message "UUID $uuid not found in file: $file"
        fi
    done
}


# Authenticate and get authorization token and API URL
RESPONSE=$(curl -s -u "$ACCOUNT_ID:$APPLICATION_KEY" \
    https://api.backblazeb2.com/b2api/v2/b2_authorize_account)

AUTH_TOKEN=$(echo $RESPONSE | jq -r '.authorizationToken')
API_URL=$(echo $RESPONSE | jq -r '.apiUrl')

if [ -z "$AUTH_TOKEN" ] || [ -z "$API_URL" ]; then
    log_message "Failed to authenticate with Backblaze B2 API."
    exit 1
else
    log_message "Successfully authenticated. Token: $AUTH_TOKEN, API URL: $API_URL"
fi

# Process each bucket
for BUCKET_ID in "${BUCKET_IDS[@]}"; do
    log_message "Processing bucket: $BUCKET_ID"

    # List the files in the bucket
    FILE_LIST_ENDPOINT="$API_URL/b2api/v2/b2_list_file_names"
    FILE_LIST=$(curl -s -H "Authorization: $AUTH_TOKEN" \
        -d "{\"bucketId\":\"$BUCKET_ID\"}" \
        "$FILE_LIST_ENDPOINT")

    if [ -z "$FILE_LIST" ] || ! echo $FILE_LIST | jq . > /dev/null 2>&1; then
        log_message "Failed to list files in bucket $BUCKET_ID. Response: $FILE_LIST"
        continue  # Skip to next bucket
    else
        FILE_COUNT=$(echo $FILE_LIST | jq '.files | length')
        log_message "Bucket $BUCKET_ID: Total files - $FILE_COUNT"
    fi

    if [ "$FILE_COUNT" -gt "$MAX_FILES" ] 2>/dev/null; then
        DELETE_COUNT=$(($FILE_COUNT - $MAX_FILES))
        log_message "Deleting $DELETE_COUNT old files in bucket $BUCKET_ID to maintain the limit."

        DELETE_FILE_ENDPOINT="$API_URL/b2api/v2/b2_delete_file_version"
        OLDEST_FILES=$(echo $FILE_LIST | jq -r '.files | sort_by(.fileName) | .[] | "\(.fileName) \(.fileId)"' | head -n $DELETE_COUNT)

        echo "$OLDEST_FILES" | while read OLDEST_FILE_NAME OLDEST_FILE_ID; do
            DELETE_RESPONSE=$(curl -s -H "Authorization: $AUTH_TOKEN" \
                -d "{\"fileName\":\"$OLDEST_FILE_NAME\",\"fileId\":\"$OLDEST_FILE_ID\"}" \
                "$DELETE_FILE_ENDPOINT")

            if [ -z "$DELETE_RESPONSE" ]; then
                log_message "Failed to delete file $OLDEST_FILE_NAME in bucket $BUCKET_ID."
            else
                 # Extract and format UUID from the filename, excluding the .zip extension
                UUID=$(echo $OLDEST_FILE_NAME | grep -oP '(\w{8})(\w{4})(\w{4})(\w{4})(\w{12})' | sed -r 's/(\w{8})(\w{4})(\w{4})(\w{4})(\w{12})/\1-\2-\3-\4-\5/')

                # Process AMP logs if flag is set
                if [ "$MODIFY_AMP_LOGS" = true ]; then
                    process_amp_logs $UUID
                fi

                log_message "Successfully deleted file $OLDEST_FILE_NAME in bucket $BUCKET_ID."
            fi
        done
    else
        log_message "No files need to be deleted in bucket $BUCKET_ID. File count is within the limit."
    fi
done

log_message "Script execution completed."
