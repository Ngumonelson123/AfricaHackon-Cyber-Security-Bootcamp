#!/bin/bash
###############################################################################
# Script Name : your_script.sh
# Author      : Nelson Ngumo
# Course      : AfricaHackon Academy - Cohort 6
# Assignment  : C3A - Create a Custom Automation Script
#
# Description : This script automates FOUR of the tasks listed in the
#               assignment:
#                 1. System maintenance   -> checks disk usage, deletes logs
#                                            older than 7 days
#                 2. File organization    -> moves .txt / .log files into a
#                                            dedicated directory
#                 3. Scheduled cleanup    -> deletes temporary files every
#                                            time the script runs
#                 4. Backup automation    -> copies important files to a
#                                            timestamped backup folder
#
#               It also implements the bonus challenge: a simple progress
#               bar and a user-confirmation prompt (read -p) before running
#               the potentially destructive steps (deleting old logs/temp
#               files).
#
# Log File    : /home/$USER/script_log.txt
# SECTION 0: CONFIGURATION
# Centralising paths here makes the script easy to re-point at different
# directories without hunting through the rest of the code.

LOG_FILE="/home/$USER/script_log.txt"
WORK_DIR="/home/$USER/c3a_workspace"      # sandbox where the demo files live
LOG_SOURCE_DIR="$WORK_DIR/logs"           # where "old" logs are checked
ORGANIZE_SOURCE_DIR="$WORK_DIR/incoming"  # where loose .txt/.log files land
ORGANIZE_DEST_DIR="$WORK_DIR/organized"   # where they get filed away
TEMP_DIR="$WORK_DIR/tmp"                  # scratch/temp files to purge
BACKUP_SOURCE_DIR="$WORK_DIR/important"   # "important" files to back up
BACKUP_DEST_DIR="$WORK_DIR/backups"       # timestamped backups go here
DISK_USAGE_THRESHOLD=80                   # percent, used in the conditional

# Make sure all the sandbox directories exist so the script can run
# end-to-end on a fresh machine (this also demonstrates -p/mkdir safety).
mkdir -p "$LOG_SOURCE_DIR" "$ORGANIZE_SOURCE_DIR" "$ORGANIZE_DEST_DIR" \
         "$TEMP_DIR" "$BACKUP_SOURCE_DIR" "$BACKUP_DEST_DIR"
# SECTION 1: LOGGING HELPER
# Every meaningful action in the script is funneled through this function so
# that both the terminal (via echo) and the log file get the same message,
# each stamped with the date/time it happened.

log_action() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# SECTION 2: SIMPLE PROGRESS BAR (BONUS)
# ---------------------------------------------------------------------------
# A lightweight text progress bar used while long-ish steps run, purely for
# a nicer user experience in the terminal.

show_progress() {
    local duration=$1
    local steps=20
    local sleep_time
    sleep_time=$(echo "$duration / $steps" | bc -l 2>/dev/null || echo 0.05)

    echo -n "Progress: ["
    for ((i = 0; i < steps; i++)); do
        echo -n "#"
        sleep "$sleep_time" 2>/dev/null
    done
    echo "] Done."
}

# ---------------------------------------------------------------------------
# SECTION 3: BANNER / SYSTEM NOTIFICATION
# ---------------------------------------------------------------------------
echo "==========================================================="
echo " AfricaHackon C3A - Custom Automation Script"
echo "==========================================================="
log_action "Script started by user: $USER"

# System notification before performing update/maintenance work, as
# required by the "User notifications" bullet in the assignment.
echo "System will reboot soon"
log_action "Displayed system notification to user."

# ---------------------------------------------------------------------------
# SECTION 4: USER CONFIRMATION (BONUS)
# ---------------------------------------------------------------------------
# Destructive actions (deleting old logs, clearing temp files) only run if
# the user explicitly agrees. This demonstrates read -p and a conditional.

read -p "Do you want to continue with maintenance & cleanup? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    log_action "User declined to continue. Exiting script safely."
    echo "No changes made. Exiting."
    exit 0
fi

log_action "User confirmed. Proceeding with automation tasks."

# ---------------------------------------------------------------------------
# SECTION 5: TASK 1 - SYSTEM MAINTENANCE
# (Check disk usage, delete logs older than 7 days)
# ---------------------------------------------------------------------------
echo ""
echo "----- Task 1: System Maintenance -----"

# Check disk usage of the root partition. df -h --output=pcent isolates the
# percentage column; tr/sed strip the '%' sign and whitespace for the
# numeric comparison in the if-statement below.
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

log_action "Current disk usage on / is ${DISK_USAGE}%."

# Conditional: warn the user if usage is above the configured threshold.
if [ "$DISK_USAGE" -ge "$DISK_USAGE_THRESHOLD" ]; then
    log_action "WARNING: Disk usage (${DISK_USAGE}%) exceeds threshold (${DISK_USAGE_THRESHOLD}%)."
    echo "WARNING: Disk usage is high (${DISK_USAGE}%)."
else
    log_action "Disk usage is within safe limits (${DISK_USAGE}%)."
    echo "Disk usage is healthy (${DISK_USAGE}%)."
fi

# Delete log files older than 7 days from the sandbox log directory.
# find ... -mtime +7 matches files last modified more than 7 days ago.
OLD_LOGS_COUNT=$(find "$LOG_SOURCE_DIR" -type f -name "*.log" -mtime +7 | wc -l)

if [ "$OLD_LOGS_COUNT" -gt 0 ]; then
    find "$LOG_SOURCE_DIR" -type f -name "*.log" -mtime +7 -exec rm -v {} \; >> "$LOG_FILE" 2>&1
    log_action "Deleted $OLD_LOGS_COUNT log file(s) older than 7 days from $LOG_SOURCE_DIR."
else
    log_action "No logs older than 7 days found in $LOG_SOURCE_DIR."
fi

show_progress 1
# SECTION 6: TASK 2 - FILE ORGANIZATION
# (Move .txt and .log files into a dedicated directory)
# ---------------------------------------------------------------------------
echo ""
echo "----- Task 2: File Organization -----"

MOVED_COUNT=0

# Loop through every .txt and .log file found in the "incoming" directory
# and move each one into the "organized" directory, logging every move.
for file in "$ORGANIZE_SOURCE_DIR"/*.txt "$ORGANIZE_SOURCE_DIR"/*.log; do
    # Guard against the literal glob string when no matches exist.
    if [ -f "$file" ]; then
        mv "$file" "$ORGANIZE_DEST_DIR/"
        log_action "Moved $(basename "$file") to $ORGANIZE_DEST_DIR."
        ((MOVED_COUNT++))
    fi
done

if [ "$MOVED_COUNT" -eq 0 ]; then
    log_action "No .txt or .log files found to organize in $ORGANIZE_SOURCE_DIR."
else
    log_action "File organization complete. $MOVED_COUNT file(s) moved."
fi

# ---------------------------------------------------------------------------
# SECTION 7: TASK 3 - SCHEDULED CLEANUP
# (Delete temporary files every time the script runs)
# ---------------------------------------------------------------------------
echo ""
echo "----- Task 3: Scheduled Cleanup -----"

TEMP_FILE_COUNT=$(find "$TEMP_DIR" -type f | wc -l)

if [ "$TEMP_FILE_COUNT" -gt 0 ]; then
    find "$TEMP_DIR" -type f -exec rm -v {} \; >> "$LOG_FILE" 2>&1
    log_action "Cleaned up $TEMP_FILE_COUNT temporary file(s) from $TEMP_DIR."
else
    log_action "No temporary files found in $TEMP_DIR. Nothing to clean."
fi

# ---------------------------------------------------------------------------
# SECTION 8: TASK 4 - BACKUP AUTOMATION
# (Copy important files to a backup folder with a timestamp)
# ---------------------------------------------------------------------------
echo ""
echo "----- Task 4: Backup Automation -----"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_TARGET="$BACKUP_DEST_DIR/backup_$TIMESTAMP"
mkdir -p "$BACKUP_TARGET"

IMPORTANT_FILE_COUNT=$(find "$BACKUP_SOURCE_DIR" -type f | wc -l)

if [ "$IMPORTANT_FILE_COUNT" -gt 0 ]; then
    cp -rv "$BACKUP_SOURCE_DIR"/* "$BACKUP_TARGET/" >> "$LOG_FILE" 2>&1
    log_action "Backed up $IMPORTANT_FILE_COUNT file(s) to $BACKUP_TARGET."
    echo "Backup created at: $BACKUP_TARGET"
else
    log_action "No important files found in $BACKUP_SOURCE_DIR to back up."
    rmdir "$BACKUP_TARGET" 2>/dev/null
fi

show_progress 1

# ---------------------------------------------------------------------------
# SECTION 9: WRAP UP
# ---------------------------------------------------------------------------
echo ""
echo "==========================================================="
log_action "Script finished successfully."
echo "All tasks complete. See $LOG_FILE for a full action log."
echo "==========================================================="

exit 0
