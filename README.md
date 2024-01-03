# AMP Backblaze B2 Rotation

This script is designed to automate the rotation of backup files generated in AMP (by Cubecoders) that are sent to Backblaze B2 storage. It manages the number of backup files in each bucket, ensuring that only the newest backups are kept up to a specified limit. Additionally, it provides an option to modify AMP's `Backups.json` files to reflect the changes in backup storage.

## Prerequisites

- Bash shell
- `curl` and `jq` installed on your system
- Access to Backblaze B2 account

## Configuration

### Setting Environment Variables

Set the following environment variables in the script:

- `ACCOUNT_ID`: Your Backblaze B2 account ID (keyID).
- `APPLICATION_KEY`: Your Backblaze B2 application key.
- `MAX_FILES`: The maximum number of backup files to keep in each bucket.
- `LOG_FILE`: Path to your log file.
- `BUCKET_IDS`: Array of your Backblaze B2 bucket IDs.
- `AMP_LOG_DIR`: Path to the your root instances directory to look for `Backups.json` files (default: `/home/amp/.ampdata/instances/`).

Example:
```bash
ACCOUNT_ID="yourAccountID"
APPLICATION_KEY="yourApplicationKey"
MAX_FILES=7
LOG_FILE="/path/to/your/logfile.log"
BUCKET_IDS=("bucket1id" "bucket2id" "bucket3id")
AMP_LOG_DIR="/home/amp/.ampdata/instances/"
```

## Usage

Run the script manually or set up a cron job for automated execution.

### Optional Feature

The script can be run with the `--modify-amp-logs` parameter to enable modification of AMP's `Backups.json` files:

```bash
/path/to/your/script.sh --modify-amp-logs
```

This will update the `Backups.json` files in `AMP_LOG_DIR` to reflect the deletion of backups from Backblaze B2 storage.

### Setting Up a Cron Job

1. Open your crontab file:
   ```bash
   crontab -e
   ```
2. Add a line to schedule the script. For example, to run it daily at 3 AM:
   ```bash
   0 3 * * * /path/to/your/script.sh --modify-amp-logs
   ```
3. Save and exit the editor.

## Log File

The script logs its activity to the specified `LOG_FILE`. You can view the log for details about each execution, including any modifications made to `Backups.json` files.

## Script Functionality

- Authenticates with the Backblaze B2 API.
- Processes each specified bucket.
- Lists and counts files in each bucket.
- Deletes the oldest files if the number of files exceeds `MAX_FILES`.
- Optionally modifies AMP's `Backups.json` files to reflect changes in backup storage.

## Note

Ensure that the script is executable:
```bash
chmod +x /path/to/your/script.sh
```

## Disclaimer

This script is provided as-is, and it's recommended to test thoroughly in your environment before using it in production.
