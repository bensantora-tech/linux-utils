#!/bin/bash
# System Health Dashboard - YAD GUI

TITLE="System Dashboard"
WIDTH=730
HEIGHT=360
LOG_FILE="$HOME/.sysdash.log"

# Gather system stats and set HEALTH_TEXT + STATUS
get_health_info() {
    CPU=$(top -bn1 -d 0.1 | grep "Cpu(s)" | tail -1 | awk '{print $2}' | cut -d'%' -f1)

    MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
    MEM_USED=$(free -m  | awk '/Mem:/ {print $3}')
    if [ "${MEM_TOTAL:-0}" -gt 0 ] 2>/dev/null; then
        MEM_PERC=$((MEM_USED * 100 / MEM_TOTAL))
    else
        MEM_PERC=0
    fi

    DISK_PERC=$(df / --output=pcent 2>/dev/null | tail -1 | tr -d '% ' || echo 0)
    UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "Unknown")
    LOAD=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs || echo "Unknown")

    STATUS="Healthy"
    if [ "${CPU%.*}" -gt 80 ] 2>/dev/null || [ "$MEM_PERC" -gt 85 ] || [ "$DISK_PERC" -gt 90 ]; then
        STATUS="High Usage"
    fi

    HEALTH_TEXT="<b>System Health Monitor</b> | Status: <b>$STATUS</b>
<span font='monospace'>
<b>CPU:</b>  ${CPU}%    <b>Mem:</b>  ${MEM_PERC}% (${MEM_USED}M/${MEM_TOTAL}M)   <b>Disk:</b> ${DISK_PERC}%
<b>Up:</b>   ${UPTIME}  <b>Load:</b> ${LOAD}</span>"
}

clear_cache() {
    yad --question --title="Confirm Action" \
        --text="Are you sure you want to clear the package cache?" \
        --button="Cancel:1" --button="Clear Cache:0" --width=350 --center
    [ $? -ne 0 ] && return

    echo "Clearing package cache..." > "$LOG_FILE"
    if command -v apt &>/dev/null; then
        sudo apt clean 2>&1 >> "$LOG_FILE"
        MSG="APT cache cleared"
    elif command -v dnf &>/dev/null; then
        sudo dnf clean all 2>&1 >> "$LOG_FILE"
        MSG="DNF cache cleared"
    elif command -v yum &>/dev/null; then
        sudo yum clean all 2>&1 >> "$LOG_FILE"
        MSG="YUM cache cleared"
    else
        MSG="No supported package manager found"
    fi
    yad --info --title="Cache Cleared" --text="$MSG" --width=300 --button="OK" --center
}

check_updates() {
    if command -v apt &>/dev/null; then
        UPDATES=$(apt list --upgradable 2>/dev/null | grep -c '/')
        if [ "$UPDATES" -gt 0 ]; then
            MSG="$UPDATES packages have available updates.\n\nRun: sudo apt upgrade"
        else
            MSG="System is up to date!"
        fi
    elif command -v dnf &>/dev/null; then
        UPDATES=$(dnf check-update 2>/dev/null | grep -c '^[a-zA-Z]')
        if [ "$UPDATES" -gt 0 ]; then
            MSG="$UPDATES packages have available updates.\n\nRun: sudo dnf upgrade"
        else
            MSG="System is up to date!"
        fi
    else
        MSG="Update check not supported for this package manager"
    fi
    yad --info --title="Updates" --text="$MSG" --width=350 --button="OK" --center
}

restart_service() {
    SERVICE_CHOICE=$(yad --list --title="Restart Service" --width=400 --height=300 \
        --column="Safe Services" \
        "NetworkManager" "bluetooth" "docker" "cups" "ssh" "nginx" "apache2" "postgresql" "mysql" "Other..." \
        --button="Cancel:1" --button="Next:0" --center)
    [ $? -ne 0 ] || [ -z "$SERVICE_CHOICE" ] && return

    SERVICE=$(echo "$SERVICE_CHOICE" | cut -d'|' -f1)

    if [ "$SERVICE" = "Other..." ]; then
        SERVICE=$(yad --entry --title="Custom Service" \
            --text="<b>WARNING:</b> Restarting critical system services can cause instability.\n\nEnter service name:" \
            --width=400 --button="Cancel:1" --button="Restart:0" --center)
        [ $? -ne 0 ] || [ -z "$SERVICE" ] && return
    fi

    yad --question --title="Confirm Restart" \
        --text="Are you sure you want to restart <b>$SERVICE</b>?" \
        --button="Cancel:1" --button="Restart:0" --width=350 --center
    if [ $? -eq 0 ]; then
        RESULT=$(sudo systemctl restart "$SERVICE" 2>&1)
        if [ $? -eq 0 ]; then
            yad --info --title="Service Restarted" \
                --text="<b>$SERVICE</b> restarted successfully." \
                --width=350 --center
        else
            yad --error --title="Restart Failed" \
                --text="Failed to restart <b>$SERVICE</b>:\n\n$RESULT" \
                --width=450 --center
        fi
    fi
}

view_logs() {
    LOG=$(yad --list --title="Select Log File" --width=350 --height=250 \
        --column="Log File" \
        "/var/log/syslog" "/var/log/auth.log" "/var/log/kern.log" "/var/log/dpkg.log" "Custom Log..." \
        --button="Cancel:1" --button="View:0" --center)
    [ $? -ne 0 ] || [ -z "$LOG" ] && return

    LOG_PATH=$(echo "$LOG" | cut -d'|' -f1)
    if [ "$LOG_PATH" = "Custom Log..." ]; then
        LOG_PATH=$(yad --file --title="Select Log File" --width=600 --height=400 --center)
    fi
    [ -z "$LOG_PATH" ] && return

    if [ -f "$LOG_PATH" ] && [ -r "$LOG_PATH" ]; then
        tail -20 "$LOG_PATH" | yad --text-info \
            --title="Log: $(basename "$LOG_PATH")" \
            --width=700 --height=400 --button="OK" --center
    else
        yad --error --title="Log Error" \
            --text="Cannot read log file: $LOG_PATH\n\nEnsure the file exists and you have permission." \
            --width=400 --center
    fi
}

disk_check() {
    df -h | yad --text-info --title="Disk Usage" \
        --width=700 --height=300 --button="OK" --center
}

# Main loop
while true; do
    get_health_info
    ACTION=$(yad --title="$TITLE" --width=$WIDTH --height=$HEIGHT \
        --text="$HEALTH_TEXT" \
        --form \
        --field="Quick Actions:CB" "Clear Cache!Check Updates!Restart Service!View Logs!Disk Check!Refresh" \
        --button="Quit:1" --button="Execute:0" \
        --center)

    RETVAL=$?
    [ $RETVAL -eq 1 ] || [ $RETVAL -eq 252 ] && exit 0

    SELECTED_ACTION=$(echo "$ACTION" | cut -d'|' -f1)

    case "$SELECTED_ACTION" in
        "Clear Cache")     clear_cache ;;
        "Check Updates")   check_updates ;;
        "Restart Service") restart_service ;;
        "View Logs")       view_logs ;;
        "Disk Check")      disk_check ;;
        "Refresh")         ;;
    esac
done
