#!/bin/sh
# shellcheck shell=dash
# NOTE: 'echo $SHELL' reports '/bin/ash' on the routers, see:
# - https://en.wikipedia.org/wiki/Almquist_shell#Embedded_Linux
# - https://github.com/koalaman/shellcheck/issues/1841
#
#
# Description: This script unlocks an CN-locked (due to laws in China) device so VPN features will be available by GL GUI
# Thread: <Due to laws, no thread available>
# Author: Admon
# Updated: 2024-05-05
# Date: 2024-05-05
SCRIPT_VERSION="2024.05.19.02"
SCRIPT_NAME="glinet-remove-chinalock.sh"
UPDATE_URL="https://raw.githubusercontent.com/Admonstrator/glinet-remove-chinalock/main/glinet-remove-chinalock.sh"
# ^ Update this block with the latest version and update URL
#
# Usage: ./glinet-remove-chinalock.sh [--help] [--new-country-code=<COUNTRY_CODE>] [--country-code=<COUNTRY_CODE>]
# Warning: This script might potentially harm your router. Use it at your own risk!
#
# Variables
FACTORY_PARTITION=""
COUNTRY_CODE="CN"
COUNTRY_CODE_NEW="US"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
INFO='\033[0m' # No Color
BACKUP_FILE="factory_partition_$(date +"%Y%m%d_%H%M%S").img"

# Functions
invoke_intro() {
    echo "┌────────────────────────────────────────────────────────────────────────┐"
    echo "│ GL.iNet router script by Admon 🦭 for the GL.iNet community            |"
    echo "| Version: $SCRIPT_VERSION                                                 |"
    echo "├────────────────────────────────────────────────────────────────────────┤"
    echo "│ WARNING: THIS SCRIPT MIGHT POTENTIALLY HARM YOUR ROUTER!               │"
    echo "│ It's only recommended to use this script if you know what you're doing.│"
    echo "├────────────────────────────────────────────────────────────────────────┤"
    echo "│ This script will remove the China lock from your GL.iNet device.       │"
    echo "│ This will allow you to use VPN features in the GL.iNet GUI.            │"
    echo "└────────────────────────────────────────────────────────────────────────┘"
}

invoke_help() {
    echo -e "\033[1mUsage:\033[0m \033[92m./glinet-remove-chinalock.sh\033[0m \033[93m[--new-country-code=<COUNTRY_CODE>] [--country-code=<COUNTRY_CODE>] [--help]\033[0m"
    echo -e "\033[1mOptions:\033[0m"
    echo -e "  \033[93m--new-country-code\033[0m   \033[97mSet the new country code (default: US)\033[0m"
    echo -e "  \033[93m--country-code\033[0m       \033[97mSet the current country code (default: CN)\033[0m"
    echo -e "  \033[93m--help\033[0m               \033[97mShow this help\033[0m"
}

invoke_convert_countrycode() {
    COUNTRY_CODE_HEX=$(echo -n "$1" | hexdump -v -e '/1 "%02X"')
    echo $COUNTRY_CODE_HEX
}

invoke_find_partition() {
    log "INFO" "Searching for factory partition by label ..."
    # Try to find the factory partition by label
    FACTORY_PARTITION=$(blkid -t PARTLABEL="factory" -o device)
    if [ -z "$FACTORY_PARTITION" ]; then
        log "WARNING" "Could not find factory partition by label"
        log "INFO" "Searching for the factory partition by MTD ..."
        # Try to find the factory partition by MTD
        FACTORY_MTD=$(awk '/Factory/ {gsub(":", "", $1); print $1}' /proc/mtd)
        FACTORY_PARTITION="/dev/mtdblock${FACTORY_MTD:3}"
        if [ ! -e "$FACTORY_PARTITION" ]; then
            log "ERROR" "Could not find factory partition"
            log "ERROR" "Please report this issue to the GitHub repository."
            exit 1
        fi
    fi
    log "SUCCESS" "Found factory partition at $FACTORY_PARTITION"
}

invoke_backup() {
    log "INFO" "Backing up factory partition ..."
    dd if=$FACTORY_PARTITION of=$BACKUP_FILE bs=2M > /dev/null 2>&1
    # Check if the backup was successful by checking the file existeINFOe
    if [ -f $BACKUP_FILE ]; then
        log "SUCCESS" "Backup successful"
        # Check the content of the backup file, must contain "firsttest" and "secondtest"
        if strings $BACKUP_FILE | grep -q "firsttest" && strings $BACKUP_FILE | grep -q "secondtest"; then
            log "SUCCESS" "Backup content verified"
            log "SUCCESS" "Backup file: /root/$BACKUP_FILE"
            fi
        else
            log "ERROR" "Backup content verification failed"
            log "ERROR" "Please report this issue to the GitHub repository."
            exit 1
        fi
}

invoke_remove_china_lock() { 
    log "INFO" "Setting country code $COUNTRY_CODE_NEW on $FACTORY_PARTITION ..."
    # Replace the country code with the new one
    printf "$(echo $COUNTRY_CODE_NEW_HEX | sed 's/../\\x&/g')" | dd of=$FACTORY_PARTITION seek=$BINARY_OFFSET bs=1 count=4 conv=notrunc > /dev/null 2>&1
    # Check if the country code was set successfully using hexdump
    if hexdump -ve '1/1 "%.2X"' $FACTORY_PARTITION | tr -d '\n' | grep -q $COUNTRY_CODE_NEW_HEX; then
        log "SUCCESS" "Country code set successfully"
    else
        log "ERROR" "Country code could not be set"
        log "ERROR" "Please report this issue to the GitHub repository."
        exit 1
    fi
}

invoke_find_countrycode()
{
    local DEVICE=$1
    local COUNTRY_CODE=$2
    local COUNTRY_CODE_HEX=$3
    log "INFO" "Searching for country code $COUNTRY_CODE ($COUNTRY_CODE_HEX) in factory partition $DEVICE ..."
    BINARY_OFFSET=$(hexdump -ve '1/1 "%.2X"' $DEVICE | tr -d '\n' | sed -n "s/\(.*\)$COUNTRY_CODE_HEX\(.*\)/\1/p" | wc -c)
    if [ -z $BINARY_OFFSET ]; then
        log "WARNING" "Could not find country code ($COUNTRY_CODE_HEX) in factory partition"
        log "ERROR" "Please report this issue to the GitHub repository."
        log "ERROR" "Error: BINARY_OFFSET is empty"
        exit 1
    else
        # Divide by 2 to get the actual offset

        # Offset should never be 0
        if [ $BINARY_OFFSET -eq 0 ]; then
            log "WARNING" "Could not find country code ($COUNTRY_CODE_HEX) in factory partition"
        else
            BINARY_OFFSET=$((BINARY_OFFSET / 2))
            BINARY_OFFSET=$((BINARY_OFFSET + 1))
            log "SUCCESS" "Found country code ($COUNTRY_CODE_HEX) at offset $BINARY_OFFSET"
        fi
    fi
}

invoke_ask() {
    echo -e "${RED}W A R N I N G${INFO}"
    echo -e "${RED}This script is HIGLY EXPERIMENTAL and NOT OFFICIALLY SUPPORTED by GL.iNet!${INFO}"
    echo -e "${RED}It could DESTROY your device and WILL VOID your warranty!${INFO}"
    echo -e "${RED}Even UNBRICKING might not be possible!${INFO}"
    echo -e "${RED}Make sure to copy the backup file to a safe place!${INFO}"
    echo -e "${RED}After running this script you need to set up the device again!${INFO}"
    echo -e "${RED}Use it at your own risk!${INFO}"

        read -p "Do you want to continue? [y/N]: " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        log "INFO" "Exiting the script"
        exit 0
    fi
}

invoke_done() {
    log "SUCCESS" "The China lock has been removed successfully"
    log "INFO" "You need to follow the instructions to get the VPN features in the GL.iNet GUI"
    log "INFO" "1. Place the backup file $BACKUP_FILE in a safe place, like a USB storage"
    log "INFO" "2. Run the command: firstboot"
    log "INFO" "3. Run the command: reboot"
    log "INFO" "4. Set up the device again"
    log "SUCCESS" "Script finished"
}

invoke_update() {
    log "INFO" "Checking for script updates"
    SCRIPT_VERSION_NEW=$(curl -s "$UPDATE_URL" | grep -o 'SCRIPT_VERSION="[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}\.[0-9]\{2\}"' | cut -d '"' -f 2 || echo "Failed to retrieve scriptversion")
    if [ -n "$SCRIPT_VERSION_NEW" ] && [ "$SCRIPT_VERSION_NEW" != "$SCRIPT_VERSION" ]; then
       log "WARNING" "A new version of the script is available: $SCRIPT_VERSION_NEW"
       log "INFO" "Updating the script ..."
       wget -qO /tmp/$SCRIPT_NAME "$UPDATE_URL"
       # Get current script path
       SCRIPT_PATH=$(readlink -f "$0")
       # Replace current script with updated script
       rm "$SCRIPT_PATH"
       mv /tmp/$SCRIPT_NAME "$SCRIPT_PATH"
       chmod +x "$SCRIPT_PATH"
       log "INFO" "The script has been updated. It will now restart ..."
       sleep 3
       exec "$SCRIPT_PATH" "$@"
    else
        log "SUCCESS" "The script is up to date"
    fi
}

invoke_check_dependencies(){
    # Check if the provided country codes are only 2 characters long
    if [ ${#COUNTRY_CODE} -ne 2 ] || [ ${#COUNTRY_CODE_NEW} -ne 2 ]; then
        log "ERROR" "Country codes must be 2 characters long"
        exit 1
    fi

    # Check if awk is installed
    if ! command -v awk > /dev/null; then
        log "ERROR" "awk is not installed"
        exit 1
    fi
}

log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local color=$INFO # Default to no color

    # Assign color based on level
    case "$level" in
        ERROR)
            level="x"
            color=$RED
            ;;
        WARNING)
            level="!"
            color=$YELLOW
            ;;
        SUCCESS)
            level="✓"
            color=$GREEN
            ;;
        INFO)
            level="→"
            ;;
    esac

    echo -e "${color}[$timestamp] [$level] $message${INFO}"
}

# Main
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --new-country-code=*) COUNTRY_CODE_NEW="${1#*=}"; shift ;;
        --country-code=*) COUNTRY_CODE="${1#*=}"; shift ;;
        --help) invoke_help; exit 0 ;;
        *) echo "Unknown option: $1"; invoke_help; exit 1 ;;
    esac
done

# Main part
invoke_update
invoke_check_dependencies
invoke_intro
invoke_ask
log "INFO" "Changing the country code from $COUNTRY_CODE to $COUNTRY_CODE_NEW"
COUNTRY_CODE_HEX=$(invoke_convert_countrycode $COUNTRY_CODE)
COUNTRY_CODE_NEW_HEX=$(invoke_convert_countrycode $COUNTRY_CODE_NEW)
invoke_find_partition
invoke_backup

log "INFO" "Try 1#"
log "INFO" "Due to different encoding of the country code, the script will search twice"
invoke_find_countrycode $FACTORY_PARTITION $COUNTRY_CODE FF${COUNTRY_CODE_HEX}
if [ $BINARY_OFFSET -eq "0" ]; then
    log "INFO" "Try #2"
    invoke_find_countrycode $FACTORY_PARTITION $COUNTRY_CODE 00${COUNTRY_CODE_HEX}
    if [ $BINARY_OFFSET -eq "0" ]; then
        log "ERROR" "Could not find country code in factory partition"
        log "ERROR" "Please report this issue to the GitHub repository."
        exit 1
    fi
fi

# All set, let's go!
invoke_remove_china_lock
invoke_done
exit 0