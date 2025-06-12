#!/bin/bash

#######################################################################
# VM Migration Status Checker
# 
# This utility script helps monitor and check the status of VMs
# and compute hosts for migration planning.
#
# Usage: ./vm-status-checker.sh [options]
#######################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [options]

Options:
    -v, --vm-list FILE      Check status of VMs from file
    -h, --hosts FILE        Check status of hosts from file
    -a, --all-hosts         Show all compute hosts and their VM counts
    -s, --summary           Show migration summary statistics
    --help                  Show this help message

Examples:
    $0 --vm-list ../examples/vm_list.txt
    $0 --hosts ../examples/target_hosts.txt
    $0 --all-hosts
    $0 --summary --vm-list ../examples/vm_list.txt
EOF
}

check_openstack_auth() {
    if ! openstack token issue &> /dev/null; then
        echo -e "${RED}ERROR: OpenStack authentication failed${NC}"
        echo "Please source your OpenStack credentials and try again"
        exit 1
    fi
    
    echo -e "${GREEN}OpenStack authentication successful${NC}"
}

get_vm_info() {
    local vm_id="$1"
    local vm_info
    
    if vm_info=$(openstack server show "$vm_id" -f json 2>/dev/null); then
        local name status host
        name=$(echo "$vm_info" | jq -r '.name')
        status=$(echo "$vm_info" | jq -r '.status')
        host=$(echo "$vm_info" | jq -r '."OS-EXT-SRV-ATTR:host"')
        
        echo "$vm_id|$name|$status|$host"
    else
        echo "$vm_id|NOT_FOUND|NOT_FOUND|NOT_FOUND"
    fi
}

check_vm_list() {
    local vm_list_file="$1"
    
    if [[ ! -f "$vm_list_file" ]]; then
        echo -e "${RED}ERROR: VM list file not found: $vm_list_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== VM Status Report ===${NC}"
    echo "VM ID|Name|Status|Host"
    echo "----------------------------------------"
    
    local total_vms=0
    local active_vms=0
    local shutoff_vms=0
    local error_vms=0
    local not_found_vms=0
    
    while IFS= read -r vm_id; do
        # Skip empty lines and comments
        if [[ -z "$vm_id" || "$vm_id" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        vm_id=$(echo "$vm_id" | xargs) # Trim whitespace
        local vm_info
        vm_info=$(get_vm_info "$vm_id")
        
        IFS='|' read -r id name status host <<< "$vm_info"
        
        case "$status" in
            "ACTIVE")
                echo -e "${GREEN}$id|$name|$status|$host${NC}"
                ((active_vms++))
                ;;
            "SHUTOFF")
                echo -e "${YELLOW}$id|$name|$status|$host${NC}"
                ((shutoff_vms++))
                ;;
            "ERROR")
                echo -e "${RED}$id|$name|$status|$host${NC}"
                ((error_vms++))
                ;;
            "NOT_FOUND")
                echo -e "${RED}$id|$name|$status|$host${NC}"
                ((not_found_vms++))
                ;;
            *)
                echo "$id|$name|$status|$host"
                ;;
        esac
        
        ((total_vms++))
    done < "$vm_list_file"
    
    echo ""
    echo -e "${BLUE}=== Summary ===${NC}"
    echo "Total VMs: $total_vms"
    echo -e "Active VMs: ${GREEN}$active_vms${NC}"
    echo -e "Shutoff VMs: ${YELLOW}$shutoff_vms${NC}"
    echo -e "Error VMs: ${RED}$error_vms${NC}"
    echo -e "Not Found VMs: ${RED}$not_found_vms${NC}"
}

check_host_list() {
    local hosts_file="$1"
    
    if [[ ! -f "$hosts_file" ]]; then
        echo -e "${RED}ERROR: Hosts file not found: $hosts_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== Host Status Report ===${NC}"
    echo "Host|VM Count|Status"
    echo "----------------------------------------"
    
    local total_hosts=0
    local available_hosts=0
    local unavailable_hosts=0
    
    while IFS= read -r hostname; do
        # Skip empty lines and comments
        if [[ -z "$hostname" || "$hostname" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        hostname=$(echo "$hostname" | xargs) # Trim whitespace
        
        # Check if host exists and get VM count
        local vm_count
        if vm_count=$(openstack hypervisor show "$hostname" -f json 2>/dev/null | jq -r '.running_vms' 2>/dev/null); then
            if [[ "$vm_count" == "null" ]]; then
                vm_count="0"
            fi
            echo -e "${GREEN}$hostname|$vm_count|Available${NC}"
            ((available_hosts++))
        else
            echo -e "${RED}$hostname|N/A|Unavailable${NC}"
            ((unavailable_hosts++))
        fi
        
        ((total_hosts++))
    done < "$hosts_file"
    
    echo ""
    echo -e "${BLUE}=== Summary ===${NC}"
    echo "Total Hosts: $total_hosts"
    echo -e "Available Hosts: ${GREEN}$available_hosts${NC}"
    echo -e "Unavailable Hosts: ${RED}$unavailable_hosts${NC}"
}

show_all_hosts() {
    echo -e "${BLUE}=== All Compute Hosts ===${NC}"
    echo "Host|VM Count|State|Status"
    echo "----------------------------------------"
    
    local hosts_info
    if hosts_info=$(openstack hypervisor list -f json 2>/dev/null); then
        echo "$hosts_info" | jq -r '.[] | "\(.["Hypervisor Hostname"])|\(.["Running VMs"])|\(.State)|\(.Status)"' | \
        while IFS='|' read -r hostname vm_count state status; do
            if [[ "$status" == "enabled" && "$state" == "up" ]]; then
                echo -e "${GREEN}$hostname|$vm_count|$state|$status${NC}"
            elif [[ "$status" == "enabled" && "$state" == "down" ]]; then
                echo -e "${YELLOW}$hostname|$vm_count|$state|$status${NC}"
            else
                echo -e "${RED}$hostname|$vm_count|$state|$status${NC}"
            fi
        done
    else
        echo -e "${RED}ERROR: Failed to retrieve hypervisor list${NC}"
        return 1
    fi
}

show_migration_summary() {
    local vm_list_file="$1"
    
    if [[ ! -f "$vm_list_file" ]]; then
        echo -e "${RED}ERROR: VM list file not found: $vm_list_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== Migration Planning Summary ===${NC}"
    
    # Count VMs by status
    local total_vms=0
    local migratable_vms=0
    local non_migratable_vms=0
    declare -A host_counts
    
    while IFS= read -r vm_id; do
        # Skip empty lines and comments
        if [[ -z "$vm_id" || "$vm_id" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        vm_id=$(echo "$vm_id" | xargs) # Trim whitespace
        local vm_info
        vm_info=$(get_vm_info "$vm_id")
        
        IFS='|' read -r id name status host <<< "$vm_info"
        
        case "$status" in
            "ACTIVE"|"SHUTOFF")
                ((migratable_vms++))
                if [[ "$host" != "NOT_FOUND" && "$host" != "null" ]]; then
                    host_counts["$host"]=$((${host_counts["$host"]:-0} + 1))
                fi
                ;;
            *)
                ((non_migratable_vms++))
                ;;
        esac
        
        ((total_vms++))
    done < "$vm_list_file"
    
    echo "Total VMs: $total_vms"
    echo -e "Migratable VMs: ${GREEN}$migratable_vms${NC}"
    echo -e "Non-migratable VMs: ${RED}$non_migratable_vms${NC}"
    echo ""
    
    echo -e "${BLUE}Current VM Distribution:${NC}"
    for host in "${!host_counts[@]}"; do
        echo "  $host: ${host_counts[$host]} VMs"
    done
    
    echo ""
    echo -e "${BLUE}Migration Recommendations:${NC}"
    if [[ $migratable_vms -gt 0 ]]; then
        echo -e "${GREEN}✓ $migratable_vms VMs can be migrated${NC}"
        echo "  - Use live migration for ACTIVE VMs"
        echo "  - Use cold migration for SHUTOFF VMs"
    fi
    
    if [[ $non_migratable_vms -gt 0 ]]; then
        echo -e "${YELLOW}⚠ $non_migratable_vms VMs require attention before migration${NC}"
        echo "  - Check VMs in ERROR state"
        echo "  - Verify VM existence"
    fi
}

main() {
    local vm_list_file=""
    local hosts_file=""
    local show_all=false
    local show_summary=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--vm-list)
                vm_list_file="$2"
                shift 2
                ;;
            -h|--hosts)
                hosts_file="$2"
                shift 2
                ;;
            -a|--all-hosts)
                show_all=true
                shift
                ;;
            -s|--summary)
                show_summary=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                echo -e "${RED}ERROR: Unknown option: $1${NC}"
                usage
                exit 1
                ;;
        esac
    done
    
    # Check OpenStack authentication
    check_openstack_auth
    echo ""
    
    # Execute requested actions
    if [[ "$show_all" == "true" ]]; then
        show_all_hosts
        echo ""
    fi
    
    if [[ -n "$vm_list_file" ]]; then
        check_vm_list "$vm_list_file"
        echo ""
    fi
    
    if [[ -n "$hosts_file" ]]; then
        check_host_list "$hosts_file"
        echo ""
    fi
    
    if [[ "$show_summary" == "true" && -n "$vm_list_file" ]]; then
        show_migration_summary "$vm_list_file"
        echo ""
    fi
    
    # If no specific action requested, show usage
    if [[ "$show_all" == "false" && -z "$vm_list_file" && -z "$hosts_file" ]]; then
        usage
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
