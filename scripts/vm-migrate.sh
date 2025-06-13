#!/bin/bash

#######################################################################
# VM Live Migration Script with Load Balancing
# 
# This script migrates VMs sequentially with proper load balancing
# across target hosts, ensuring only one migration at a time.
#
# Features:
# - Sequential migration (one VM at a time)
# - Load balancing across target hosts
# - Live migration for active VMs
# - Cold migration for shutoff VMs
# - Comprehensive error handling and logging
#
# Usage: ./vm-migrate.sh <vm_list_file> <target_hosts_file>
#######################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/config"

# Default configuration file
DEFAULT_CONFIG="$CONFIG_DIR/migration.conf"

# Logging setup
LOG_FILE="$LOG_DIR/migration_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="$LOG_DIR/migration_errors_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#######################################################################
# Utility Functions
#######################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write to log file (create if doesn't exist, ignore errors)
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    
    case "$level" in
        ERROR)
            echo "[$timestamp] [$level] $message" >> "$ERROR_LOG" 2>/dev/null || true
            echo -e "${RED}[$level] $message${NC}" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[$level] $message${NC}" >&2
            ;;
        SUCCESS)
            echo -e "${GREEN}[$level] $message${NC}" >&2
            ;;
        INFO)
            echo -e "${BLUE}[$level] $message${NC}" >&2
            ;;
        DEBUG)
            # Show debug messages only in verbose mode
            if [[ "${VERBOSE:-false}" == "true" ]]; then
                echo -e "${BLUE}[$level] $message${NC}" >&2
            fi
            ;;
        *)
            echo "[$level] $message" >&2
            ;;
    esac
}

usage() {
    cat << EOF
Usage: $0 <vm_list_file> <target_hosts_file> [options]

Arguments:
    vm_list_file        File containing VM IDs (one per line)
    target_hosts_file   File containing target host names (one per line)

Options:
    -c, --config FILE   Configuration file (default: $DEFAULT_CONFIG)
    -d, --dry-run       Show what would be done without executing
    -h, --help          Show this help message
    -v, --verbose       Enable verbose logging
    --max-retries N     Maximum retry attempts per VM (default: 3)
    --timeout N         Migration timeout in seconds (default: 600)

Examples:
    $0 vm_list.txt target_hosts.txt
    $0 vm_list.txt target_hosts.txt --dry-run
    $0 vm_list.txt target_hosts.txt --config custom.conf --verbose
EOF
}

check_dependencies() {
    local deps=("openstack" "jq")  # Removed nova as it's not strictly required
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        log "ERROR" "Missing dependencies: ${missing_deps[*]}"
        log "ERROR" "Please install missing dependencies and try again"
        if [[ "$DRY_RUN" != "true" ]]; then
            exit 1
        else
            log "WARN" "Continuing with dry run despite missing dependencies"
        fi
    fi
    
    log "INFO" "Dependencies check passed"
}

check_openstack_auth() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Skipping OpenStack authentication check in dry-run mode"
        return 0
    fi
    
    if ! openstack token issue &> /dev/null; then
        log "ERROR" "OpenStack authentication failed"
        log "ERROR" "Please source your OpenStack credentials and try again"
        exit 1
    fi
    
    log "INFO" "OpenStack authentication successful"
}

#######################################################################
# VM and Host Management Functions
#######################################################################

get_vm_status() {
    local vm_id="$1"
    
    local status
    status=$(openstack server show "$vm_id" -f json 2>/dev/null | jq -r '.status' 2>/dev/null) || status=""
    
    if [[ "$status" == "null" || -z "$status" ]]; then
        echo "NOT_FOUND"
    else
        echo "$status"
    fi
}

get_vm_host() {
    local vm_id="$1"
    
    local host
    host=$(openstack server show "$vm_id" -f json 2>/dev/null | jq -r '."OS-EXT-SRV-ATTR:host"' 2>/dev/null) || host=""
    
    if [[ "$host" == "null" || -z "$host" ]]; then
        echo "UNKNOWN"
    else
        echo "$host"
    fi
}

get_host_vm_count() {
    local hostname="$1"
    
    local count
    count=$(openstack server list --host "$hostname" --all-projects -f json 2>/dev/null | jq '. | length' 2>/dev/null) || count=""
    
    if [[ "$count" == "null" || -z "$count" ]]; then
        echo "0"
    else
        echo "$count"
    fi
}

find_best_target_host() {
    local current_host="$1"
    declare -n target_hosts_ref_find=$2
    local best_host=""
    local min_count=999999
    
    # Check if current host is already in target hosts list
    for host in "${target_hosts_ref_find[@]}"; do
        if [[ "$host" == "$current_host" ]]; then
            log "INFO" "VM is already on target host $current_host - no migration needed"
            return 2  # Special return code for "already on target host"
        fi
    done
    
    # Find best target host (excluding current host)
    for host in "${target_hosts_ref_find[@]}"; do
        local vm_count
        vm_count=$(get_host_vm_count "$host")
        
        # Log debug info to stderr/log only, never stdout
        log "DEBUG" "Host $host has $vm_count VMs"
        
        if [[ "$vm_count" -lt "$min_count" ]]; then
            min_count="$vm_count"
            best_host="$host"
        fi
    done
    
    if [[ -z "$best_host" ]]; then
        log "ERROR" "No suitable target host found"
        return 1
    fi
    
    # Ensure only the best host is output to stdout
    printf "%s" "$best_host"
    return 0
}

#######################################################################
# Migration Functions
#######################################################################

wait_for_migration_completion() {
    local vm_id="$1"
    local target_host="$2"
    local timeout="${3:-600}"
    local start_time
    start_time=$(date +%s)
    
    log "INFO" "Waiting for migration completion (timeout: ${timeout}s)"
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            log "ERROR" "Migration timeout reached ($timeout seconds)"
            return 1
        fi
        
        local status
        status=$(get_vm_status "$vm_id")
        local current_host
        current_host=$(get_vm_host "$vm_id")
        
        case "$status" in
            "ACTIVE")
                if [[ "$current_host" == "$target_host" ]]; then
                    log "SUCCESS" "Migration completed successfully"
                    log "INFO" "VM $vm_id is now ACTIVE on host $target_host"
                    return 0
                fi
                ;;
            "MIGRATING")
                log "INFO" "Migration in progress... (${elapsed}s elapsed)"
                ;;
            "ERROR")
                log "ERROR" "VM entered ERROR state during migration"
                return 1
                ;;
            "NOT_FOUND")
                log "ERROR" "VM not found during migration check"
                return 1
                ;;
            *)
                log "WARN" "Unexpected VM status during migration: $status"
                ;;
        esac
        
        sleep 10
    done
}

perform_live_migration() {
    local vm_id="$1"
    local target_host="$2"
    local timeout="${3:-600}"
    
    log "INFO" "Starting live migration of VM $vm_id to host $target_host"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Would execute: openstack server migrate --live-migration --host $target_host $vm_id"
        return 0
    fi
    
    if ! openstack server migrate --live-migration --host "$target_host" "$vm_id"; then
        log "ERROR" "Failed to initiate live migration for VM $vm_id"
        return 1
    fi
    
    log "INFO" "Live migration initiated successfully"
    
    if ! wait_for_migration_completion "$vm_id" "$target_host" "$timeout"; then
        log "ERROR" "Live migration failed or timed out"
        return 1
    fi
    
    return 0
}

perform_cold_migration() {
    local vm_id="$1"
    local target_host="$2"
    local timeout="${3:-600}"
    
    log "INFO" "Starting cold migration of VM $vm_id to host $target_host"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Would execute: openstack server migrate --host $target_host $vm_id"
        log "INFO" "[DRY RUN] Would execute: openstack server resize confirm $vm_id"
        return 0
    fi
    
    if ! openstack server migrate --host "$target_host" "$vm_id"; then
        log "ERROR" "Failed to initiate cold migration for VM $vm_id"
        return 1
    fi
    
    log "INFO" "Cold migration initiated successfully"
    
    # Wait for migration to complete and VM to be in VERIFY_RESIZE state
    local start_time
    start_time=$(date +%s)
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            log "ERROR" "Cold migration timeout reached ($timeout seconds)"
            return 1
        fi
        
        local status
        status=$(get_vm_status "$vm_id")
        
        case "$status" in
            "VERIFY_RESIZE")
                log "INFO" "Cold migration completed, confirming resize"
                if ! openstack server resize --confirm "$vm_id"; then
                    log "ERROR" "Failed to confirm resize for VM $vm_id"
                    return 1
                fi
                log "SUCCESS" "Cold migration completed and confirmed"
                return 0
                ;;
            "MIGRATING")
                log "INFO" "Cold migration in progress... (${elapsed}s elapsed)"
                ;;
            "ERROR")
                log "ERROR" "VM entered ERROR state during cold migration"
                return 1
                ;;
            "NOT_FOUND")
                log "ERROR" "VM not found during migration check"
                return 1
                ;;
            *)
                log "INFO" "Cold migration status: $status (${elapsed}s elapsed)"
                ;;
        esac
        
        sleep 10
    done
}

migrate_vm() {
    local vm_id="$1"
    declare -n target_hosts_ref=$2
    local max_retries="${3:-3}"
    local timeout="${4:-600}"
    
    log "INFO" "Processing VM: $vm_id"
    
    # In dry-run mode, simulate the process without calling OpenStack
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Simulating migration for VM $vm_id"
        log "INFO" "[DRY RUN] Would check VM status and current host"
        log "INFO" "[DRY RUN] Would select best target host from available hosts"
        log "INFO" "[DRY RUN] Would perform migration based on VM state"
        log "SUCCESS" "[DRY RUN] VM $vm_id migration simulation completed"
        return 0
    fi
    
    # Get VM status and current host
    local vm_status
    vm_status=$(get_vm_status "$vm_id")
    
    if [[ "$vm_status" == "NOT_FOUND" ]]; then
        log "ERROR" "VM $vm_id not found"
        return 1
    fi
    
    local current_host
    current_host=$(get_vm_host "$vm_id")
    
    log "INFO" "VM $vm_id status: $vm_status, current host: $current_host"
    
    # Find best target host
    local target_host
    local find_result=0
    
    target_host=$(find_best_target_host "$current_host" target_hosts_ref)
    find_result=$?
    
    if [[ $find_result -eq 2 ]]; then
        # VM is already on a target host, no migration needed
        return 0
    elif [[ $find_result -ne 0 ]]; then
        log "ERROR" "Failed to find suitable target host for VM $vm_id"
        return 1
    fi
    
    log "INFO" "Selected target host: $target_host (current load: $(get_host_vm_count "$target_host") VMs)"
    
    # Perform migration based on VM status
    local retries=0
    local migration_success=false
    
    while [[ $retries -lt $max_retries && "$migration_success" == "false" ]]; do
        if [[ $retries -gt 0 ]]; then
            log "INFO" "Retry attempt $retries/$max_retries for VM $vm_id"
        fi
        
        case "$vm_status" in
            "ACTIVE")
                if perform_live_migration "$vm_id" "$target_host" "$timeout"; then
                    migration_success=true
                else
                    log "WARN" "Live migration failed for VM $vm_id (attempt $((retries + 1)))"
                fi
                ;;
            "SHUTOFF")
                if perform_cold_migration "$vm_id" "$target_host" "$timeout"; then
                    migration_success=true
                else
                    log "WARN" "Cold migration failed for VM $vm_id (attempt $((retries + 1)))"
                fi
                ;;
            *)
                log "ERROR" "VM $vm_id is in unsupported state for migration: $vm_status"
                return 1
                ;;
        esac
        
        ((retries++))
        
        if [[ "$migration_success" == "false" && $retries -lt $max_retries ]]; then
            log "INFO" "Waiting 30 seconds before retry..."
            sleep 30
        fi
    done
    
    if [[ "$migration_success" == "true" ]]; then
        log "SUCCESS" "VM $vm_id migrated successfully to $target_host"
        return 0
    else
        log "ERROR" "Failed to migrate VM $vm_id after $max_retries attempts"
        return 1
    fi
}

#######################################################################
# Main Functions
#######################################################################

load_config() {
    local config_file="${1:-$DEFAULT_CONFIG}"
    
    if [[ -f "$config_file" ]]; then
        log "INFO" "Loading configuration from $config_file"
        # shellcheck source=/dev/null
        source "$config_file"
    else
        log "WARN" "Configuration file not found: $config_file, using defaults"
    fi
}

validate_files() {
    local vm_list_file="$1"
    local target_hosts_file="$2"
    
    if [[ ! -f "$vm_list_file" ]]; then
        log "ERROR" "VM list file not found: $vm_list_file"
        return 1
    fi
    
    if [[ ! -f "$target_hosts_file" ]]; then
        log "ERROR" "Target hosts file not found: $target_hosts_file"
        return 1
    fi
    
    if [[ ! -s "$vm_list_file" ]]; then
        log "ERROR" "VM list file is empty: $vm_list_file"
        return 1
    fi
    
    if [[ ! -s "$target_hosts_file" ]]; then
        log "ERROR" "Target hosts file is empty: $target_hosts_file"
        return 1
    fi
    
    log "INFO" "Input files validation passed"
    return 0
}

main() {
    local vm_list_file=""
    local target_hosts_file=""
    local config_file="$DEFAULT_CONFIG"
    local dry_run=false
    local verbose=false
    local max_retries=3
    local timeout=600
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --max-retries)
                max_retries="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            -*)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$vm_list_file" ]]; then
                    vm_list_file="$1"
                elif [[ -z "$target_hosts_file" ]]; then
                    target_hosts_file="$1"
                else
                    log "ERROR" "Too many arguments"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Check required arguments
    if [[ -z "$vm_list_file" || -z "$target_hosts_file" ]]; then
        log "ERROR" "Missing required arguments"
        usage
        exit 1
    fi
    
    # Set global variables
    export DRY_RUN="$dry_run"
    export VERBOSE="$verbose"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    log "INFO" "Starting VM migration script"
    log "INFO" "VM list file: $vm_list_file"
    log "INFO" "Target hosts file: $target_hosts_file"
    log "INFO" "Max retries: $max_retries"
    log "INFO" "Timeout: $timeout seconds"
    log "INFO" "Dry run: $dry_run"
    log "INFO" "Verbose: $verbose"
    
    # Load configuration
    load_config "$config_file"
    
    # Validate input files
    if ! validate_files "$vm_list_file" "$target_hosts_file"; then
        exit 1
    fi
    
    # Check dependencies and authentication
    check_dependencies
    check_openstack_auth
    
    # Load VM list and target hosts
    mapfile -t vm_list_raw < <(grep -v '^#' "$vm_list_file" | grep -v '^[[:space:]]*$')
    mapfile -t target_hosts < <(grep -v '^#' "$target_hosts_file" | grep -v '^[[:space:]]*$')
    
    # Filter VM list to remove any remaining empty entries
    vm_list=()
    for vm in "${vm_list_raw[@]}"; do
        vm=$(echo "$vm" | xargs) # Trim whitespace
        if [[ -n "$vm" ]]; then
            vm_list+=("$vm")
        fi
    done
    
    log "INFO" "Loaded ${#vm_list[@]} VMs and ${#target_hosts[@]} target hosts"
    
    if [[ ${#vm_list[@]} -eq 0 ]]; then
        log "ERROR" "No VMs found in list file"
        exit 1
    fi
    
    if [[ ${#target_hosts[@]} -eq 0 ]]; then
        log "ERROR" "No target hosts found in hosts file"
        exit 1
    fi
    
    # Migration statistics
    local total_vms=${#vm_list[@]}
    local successful_migrations=0
    local failed_migrations=0
    local start_time
    start_time=$(date +%s)
    
    log "INFO" "Starting migration of $total_vms VMs"
    
    # Process each VM sequentially
    local current_vm=0
    
    for vm_id in "${vm_list[@]}"; do
        current_vm=$((current_vm + 1))
        
        log "INFO" "=== Processing VM $vm_id ($current_vm/$total_vms) ==="
        
        # Use error handling to prevent script exit on individual VM failures
        set +e  # Temporarily disable exit on error for this section
        migrate_vm "$vm_id" target_hosts "$max_retries" "$timeout"
        local migration_result=$?
        set -e  # Re-enable exit on error
        
        if [[ $migration_result -eq 0 ]]; then
            successful_migrations=$((successful_migrations + 1))
            log "SUCCESS" "VM $vm_id migration completed"
        else
            failed_migrations=$((failed_migrations + 1))
            log "ERROR" "VM $vm_id migration failed"
        fi
        
        log "INFO" "Progress: $current_vm/$total_vms completed (Success: $successful_migrations, Failed: $failed_migrations)"
        log "INFO" "=== End processing VM $vm_id ==="
        log "INFO" ""  # Empty line
        
        # Small delay between migrations to avoid overwhelming the system
        if [[ "$dry_run" == "false" ]]; then
            sleep 5
        fi
    done
    
    # Final statistics
    local end_time
    end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    log "INFO" "=== Migration Summary ==="
    log "INFO" "Total VMs processed: $total_vms"
    log "SUCCESS" "Successful migrations: $successful_migrations"
    if [[ $failed_migrations -eq 0 ]]; then
        log "INFO" "Failed migrations: $failed_migrations"
    else
        log "ERROR" "Failed migrations: $failed_migrations"
    fi
    log "INFO" "Total time: $total_time seconds"
    log "INFO" "Log file: $LOG_FILE"
    
    if [[ $failed_migrations -gt 0 ]]; then
        log "ERROR" "Error log: $ERROR_LOG"
        exit 1
    else
        log "SUCCESS" "All migrations completed successfully!"
        exit 0
    fi
}

# Run main function with all arguments
main "$@"
