# VM Migration Tools - Windows Usage Guide

## Quick Start for Windows Users

### 1. Validate Setup
```powershell
.\scripts\vm-migrate-wrapper.ps1 -Action validate
```

### 2. Check VM Status
```powershell
# Check all compute hosts
.\scripts\vm-migrate-wrapper.ps1 -Action status -AllHosts

# Check specific VM list
.\scripts\vm-migrate-wrapper.ps1 -Action status -VmListFile "examples\vm_list.txt"

# Get migration planning summary
.\scripts\vm-migrate-wrapper.ps1 -Action status -VmListFile "examples\vm_list.txt" -Summary
```

### 3. Run Migration
```powershell
# Dry run (test without making changes)
.\scripts\vm-migrate-wrapper.ps1 -Action migrate -VmListFile "examples\vm_list.txt" -HostsFile "examples\target_hosts.txt" -DryRun

# Actual migration with verbose output
.\scripts\vm-migrate-wrapper.ps1 -Action migrate -VmListFile "examples\vm_list.txt" -HostsFile "examples\target_hosts.txt" -Verbose

# Migration with custom settings
.\scripts\vm-migrate-wrapper.ps1 -Action migrate -VmListFile "my_vms.txt" -HostsFile "my_hosts.txt" -MaxRetries 5 -Timeout 900
```

## PowerShell Wrapper Parameters

### Common Parameters
- `-Action`: Required. Choose from "migrate", "status", or "validate"
- `-VmListFile`: Path to VM list file (default: examples\vm_list.txt)
- `-HostsFile`: Path to target hosts file (default: examples\target_hosts.txt)

### Migration Parameters
- `-DryRun`: Test migration without making changes
- `-Verbose`: Enable detailed logging
- `-ConfigFile`: Custom configuration file
- `-MaxRetries`: Maximum retry attempts (default: 3)
- `-Timeout`: Migration timeout in seconds (default: 600)

### Status Check Parameters
- `-AllHosts`: Show all compute hosts
- `-Summary`: Show migration planning summary

## File Preparation

### 1. Update VM List (examples\vm_list.txt)
```
# Replace with your actual VM IDs
vm-12345678-1234-1234-1234-123456789012
vm-87654321-4321-4321-4321-210987654321
vm-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
```

### 2. Update Target Hosts (examples\target_hosts.txt)
```
# Replace with your actual compute host names
compute-node-01.example.com
compute-node-02.example.com
compute-node-03.example.com
```

### 3. Configure OpenStack Credentials
Copy and modify the example credentials file:
```powershell
Copy-Item examples\openstack-credentials-template.sh my-openstack-credentials.sh
# Edit my-openstack-credentials.sh with your actual credentials
```

Then source the credentials in your bash environment before running migrations.

## Prerequisites Check

Before running migrations, ensure:

1. **Bash Environment**: WSL or Git Bash installed
2. **OpenStack Client**: Installed in your bash environment
3. **jq**: JSON processor installed
4. **Credentials**: OpenStack credentials configured
5. **Network Access**: Can reach OpenStack API endpoints

## Common Usage Patterns

### Development/Testing Workflow
```powershell
# 1. Validate setup
.\scripts\vm-migrate-wrapper.ps1 -Action validate

# 2. Check VM status
.\scripts\vm-migrate-wrapper.ps1 -Action status -VmListFile "dev_vms.txt" -Summary

# 3. Test migration
.\scripts\vm-migrate-wrapper.ps1 -Action migrate -VmListFile "dev_vms.txt" -HostsFile "dev_hosts.txt" -DryRun

# 4. Execute migration
.\scripts\vm-migrate-wrapper.ps1 -Action migrate -VmListFile "dev_vms.txt" -HostsFile "dev_hosts.txt" -Verbose
```

### Production Workflow
```powershell
# 1. Plan migration
.\scripts\vm-migrate-wrapper.ps1 -Action status -AllHosts
.\scripts\vm-migrate-wrapper.ps1 -Action status -VmListFile "prod_vms.txt" -Summary

# 2. Test migration
.\scripts\vm-migrate-wrapper.ps1 -Action migrate -VmListFile "prod_vms.txt" -HostsFile "prod_hosts.txt" -DryRun

# 3. Execute with extended timeout
.\scripts\vm-migrate-wrapper.ps1 -Action migrate -VmListFile "prod_vms.txt" -HostsFile "prod_hosts.txt" -Timeout 1800 -MaxRetries 5
```

## Troubleshooting

### Common Issues and Solutions

1. **"No bash environment found"**
   - Install WSL: `wsl --install`
   - Or install Git for Windows

2. **"OpenStack authentication failed"**
   - Source credentials in bash: `source my-openstack-credentials.sh`
   - Verify credentials: `openstack token issue`

3. **"jq not found"**
   - Install in WSL: `sudo apt install jq`
   - Install in Git Bash (requires additional setup)

4. **Permission denied errors**
   - Make scripts executable: `chmod +x scripts/*.sh`

5. **PowerShell execution policy**
   - Allow script execution: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Getting Help

View detailed help for any script:
```bash
# In bash environment
./scripts/vm-migrate.sh --help
./scripts/vm-status-checker.sh --help
```

### Log Files

Migration logs are stored in the `logs\` directory:
- `migration_YYYYMMDD_HHMMSS.log`: Main log file
- `migration_errors_YYYYMMDD_HHMMSS.log`: Error log file

## Examples

See the `examples\` directory for:
- `vm_list.txt`: Sample VM list format
- `target_hosts.txt`: Sample hosts list format
- `openstack-credentials-template.sh`: Credentials template
