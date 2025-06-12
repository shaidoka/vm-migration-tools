#!/bin/bash

#######################################################################
# VM Migration Tools Setup Validator
# 
# This script validates the setup and dependencies for the VM migration tools
#######################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== VM Migration Tools Setup Validator ===${NC}\n"

# Check script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}Project Structure Check:${NC}"

# Check required directories
required_dirs=("scripts" "config" "examples" "logs" ".github" ".vscode")
for dir in "${required_dirs[@]}"; do
    if [[ -d "$PROJECT_ROOT/$dir" ]]; then
        echo -e "  ✓ ${GREEN}$dir/ directory exists${NC}"
    else
        echo -e "  ✗ ${RED}$dir/ directory missing${NC}"
    fi
done

echo ""

# Check required files
echo -e "${BLUE}Required Files Check:${NC}"
required_files=(
    "scripts/vm-migrate.sh"
    "scripts/vm-status-checker.sh"
    "config/migration.conf"
    "examples/vm_list.txt"
    "examples/target_hosts.txt"
    "README.md"
    ".github/copilot-instructions.md"
)

for file in "${required_files[@]}"; do
    if [[ -f "$PROJECT_ROOT/$file" ]]; then
        echo -e "  ✓ ${GREEN}$file exists${NC}"
    else
        echo -e "  ✗ ${RED}$file missing${NC}"
    fi
done

echo ""

# Check script permissions
echo -e "${BLUE}Script Permissions Check:${NC}"
script_files=("scripts/vm-migrate.sh" "scripts/vm-status-checker.sh" "scripts/setup-validator.sh")
for script in "${script_files[@]}"; do
    if [[ -f "$PROJECT_ROOT/$script" ]]; then
        if [[ -x "$PROJECT_ROOT/$script" ]]; then
            echo -e "  ✓ ${GREEN}$script is executable${NC}"
        else
            echo -e "  ⚠ ${YELLOW}$script needs execute permission${NC}"
            echo -e "    Run: chmod +x $script"
        fi
    fi
done

echo ""

# Check dependencies
echo -e "${BLUE}Dependencies Check:${NC}"
deps=("openstack" "jq" "bash")
for dep in "${deps[@]}"; do
    if command -v "$dep" &> /dev/null; then
        version=""
        case "$dep" in
            "bash")
                version=" ($(bash --version | head -1 | cut -d' ' -f4))"
                ;;
            "jq")
                version=" ($(jq --version 2>/dev/null || echo 'unknown'))"
                ;;
            "openstack")
                version=" ($(openstack --version 2>/dev/null | head -1 || echo 'unknown'))"
                ;;
        esac
        echo -e "  ✓ ${GREEN}$dep is installed${version}${NC}"
    else
        echo -e "  ✗ ${RED}$dep is not installed${NC}"
        case "$dep" in
            "jq")
                echo -e "    Install with: ${YELLOW}sudo apt-get install jq${NC} (Ubuntu/Debian)"
                echo -e "                  ${YELLOW}sudo yum install jq${NC} (RHEL/CentOS)"
                ;;
            "openstack")
                echo -e "    Install with: ${YELLOW}pip install python-openstackclient${NC}"
                ;;
        esac
    fi
done

echo ""

# Check OpenStack authentication (optional)
echo -e "${BLUE}OpenStack Authentication Check:${NC}"
if command -v openstack &> /dev/null; then
    if openstack token issue &> /dev/null; then
        echo -e "  ✓ ${GREEN}OpenStack authentication successful${NC}"
        
        # Get additional info
        project_name=$(openstack token issue -f value -c project_name 2>/dev/null || echo "unknown")
        user_name=$(openstack token issue -f value -c user_name 2>/dev/null || echo "unknown")
        echo -e "    Project: ${BLUE}$project_name${NC}"
        echo -e "    User: ${BLUE}$user_name${NC}"
    else
        echo -e "  ⚠ ${YELLOW}OpenStack authentication not configured${NC}"
        echo -e "    Please source your OpenStack credentials:"
        echo -e "    ${YELLOW}source openstack-credentials.sh${NC}"
    fi
else
    echo -e "  ⚠ ${YELLOW}OpenStack CLI not available - skipping auth check${NC}"
fi

echo ""

# Configuration check
echo -e "${BLUE}Configuration Check:${NC}"
config_file="$PROJECT_ROOT/config/migration.conf"
if [[ -f "$config_file" ]]; then
    echo -e "  ✓ ${GREEN}Configuration file exists${NC}"
    
    # Check if config file has execute permission (it shouldn't)
    if [[ -x "$config_file" ]]; then
        echo -e "  ⚠ ${YELLOW}Configuration file should not be executable${NC}"
        echo -e "    Run: chmod 644 $config_file"
    fi
else
    echo -e "  ✗ ${RED}Configuration file missing${NC}"
fi

echo ""

# Examples check
echo -e "${BLUE}Examples Check:${NC}"
example_files=("examples/vm_list.txt" "examples/target_hosts.txt")
for example in "${example_files[@]}"; do
    if [[ -f "$PROJECT_ROOT/$example" ]]; then
        line_count=$(grep -v '^#' "$PROJECT_ROOT/$example" | grep -v '^[[:space:]]*$' | wc -l)
        echo -e "  ✓ ${GREEN}$example exists ($line_count example entries)${NC}"
    else
        echo -e "  ✗ ${RED}$example missing${NC}"
    fi
done

echo ""

# Final recommendation
echo -e "${BLUE}=== Setup Summary ===${NC}"
echo -e "If all checks passed, you can proceed with:"
echo -e "1. ${YELLOW}Update examples/vm_list.txt with your VM IDs${NC}"
echo -e "2. ${YELLOW}Update examples/target_hosts.txt with your compute hosts${NC}"
echo -e "3. ${YELLOW}Source your OpenStack credentials${NC}"
echo -e "4. ${YELLOW}Run a dry-run test:${NC}"
echo -e "   ${BLUE}./scripts/vm-migrate.sh examples/vm_list.txt examples/target_hosts.txt --dry-run${NC}"

echo ""
echo -e "${GREEN}Setup validation complete!${NC}"
