# VM Migration Tools

A comprehensive bash script solution for OpenStack VM live migration with load balancing, sequential processing, and robust error handling.

## Features

- **Sequential Migration**: Ensures only one VM is migrated at a time to prevent resource conflicts
- **Load Balancing**: Automatically distributes VMs across target hosts based on current VM count
- **Smart Migration**: Automatically chooses live migration for active VMs and cold migration for shutoff VMs
- **Robust Error Handling**: Comprehensive validation, retry logic, and detailed logging
- **Status Monitoring**: Real-time migration progress tracking and completion verification
- **Comprehensive Logging**: Detailed logs with timestamps, error tracking, and migration statistics
- **Dry Run Support**: Test migrations without actually moving VMs
- **Configuration Management**: Flexible configuration file support
- **Status Checker**: Utility script for monitoring VM and host status

## Prerequisites

- OpenStack environment with Nova API access
- Required tools installed:
  - `openstack` CLI client
  - `nova` CLI client (optional, for some advanced features)
  - `jq` for JSON parsing
- Valid OpenStack credentials sourced in environment
- Bash 4.0+ (for associative arrays)

## Installation

1. Clone or download the VM migration tools to your system:
```bash
git clone <repository> vm-migration-tools
cd vm-migration-tools
```

2. Make scripts executable:
```bash
chmod +x scripts/*.sh
```

3. Install dependencies (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install jq python3-openstackclient
```

4. Install dependencies (RHEL/CentOS):
```bash
sudo yum install jq python3-openstackclient
```

## Quick Start

1. **Source your OpenStack credentials**:
```bash
source openstack-credentials.sh
```

2. **Create VM list file** (see examples/vm_list.txt):
```
vm-12345678-1234-1234-1234-123456789012
vm-87654321-4321-4321-4321-210987654321
```

3. **Create target hosts file** (see examples/target_hosts.txt):
```
compute-node-01.example.com
compute-node-02.example.com
compute-node-03.example.com
```

4. **Run a dry-run to test**:
```bash
./scripts/vm-migrate.sh examples/vm_list.txt examples/target_hosts.txt --dry-run
```

5. **Execute the migration**:
```bash
./scripts/vm-migrate.sh examples/vm_list.txt examples/target_hosts.txt
```

## Usage

### Main Migration Script

```bash
./scripts/vm-migrate.sh <vm_list_file> <target_hosts_file> [options]
```

#### Arguments:
- `vm_list_file`: File containing VM IDs (one per line)
- `target_hosts_file`: File containing target host names (one per line)

#### Options:
- `-c, --config FILE`: Configuration file (default: config/migration.conf)
- `-d, --dry-run`: Show what would be done without executing
- `-h, --help`: Show help message
- `-v, --verbose`: Enable verbose logging
- `--max-retries N`: Maximum retry attempts per VM (default: 3)
- `--timeout N`: Migration timeout in seconds (default: 600)

#### Examples:
```bash
# Basic migration
./scripts/vm-migrate.sh vm_list.txt target_hosts.txt

# Dry run with custom configuration
./scripts/vm-migrate.sh vm_list.txt target_hosts.txt --dry-run --config custom.conf

# Verbose mode with custom timeout
./scripts/vm-migrate.sh vm_list.txt target_hosts.txt --verbose --timeout 900
```

### Status Checker Script

```bash
./scripts/vm-status-checker.sh [options]
```

#### Options:
- `-v, --vm-list FILE`: Check status of VMs from file
- `-h, --hosts FILE`: Check status of hosts from file
- `-a, --all-hosts`: Show all compute hosts and their VM counts
- `-s, --summary`: Show migration summary statistics
- `--help`: Show help message

#### Examples:
```bash
# Check VM status
./scripts/vm-status-checker.sh --vm-list examples/vm_list.txt

# Check host status
./scripts/vm-status-checker.sh --hosts examples/target_hosts.txt

# Show all compute hosts
./scripts/vm-status-checker.sh --all-hosts

# Full migration planning report
./scripts/vm-status-checker.sh --summary --vm-list examples/vm_list.txt
```

## Configuration

The migration script supports extensive configuration through the `config/migration.conf` file. Key settings include:

- **Migration Settings**: Retry counts, timeouts, delays
- **OpenStack Settings**: API versions, authentication
- **Logging Settings**: Log levels, debug options
- **Migration Behavior**: Enable/disable migration types
- **Load Balancing**: Strategy selection
- **Safety Settings**: Confirmation requirements
- **Notifications**: Email/webhook integration (if implemented)

### Example Configuration:
```bash
# Migration settings
DEFAULT_MAX_RETRIES=5
DEFAULT_TIMEOUT=900

# Migration behavior
ENABLE_LIVE_MIGRATION=true
ENABLE_COLD_MIGRATION=true
SKIP_SAME_HOST=true

# Load balancing
LOAD_BALANCE_STRATEGY=vm_count
```

## File Formats

### VM List File Format
```
# Lines starting with # are comments
# Empty lines are ignored

# Production VMs
vm-12345678-1234-1234-1234-123456789012
vm-87654321-4321-4321-4321-210987654321

# Development VMs
vm-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
```

### Target Hosts File Format
```
# Lines starting with # are comments
# Empty lines are ignored

# Production compute nodes
compute-node-01.example.com
compute-node-02.example.com
compute-node-03.example.com
```

## Migration Process

The script follows this process for each VM:

1. **Validation**: Check VM existence and current status
2. **Host Selection**: Find the target host with lowest VM count
3. **Migration Type Decision**:
   - ACTIVE VMs → Live Migration
   - SHUTOFF VMs → Cold Migration
   - Other states → Skip with error
4. **Migration Execution**: Perform the migration with retries
5. **Verification**: Wait for completion and verify success
6. **Logging**: Record results and update statistics

## Load Balancing

The script automatically balances VMs across target hosts by:

1. Counting current VMs on each target host
2. Selecting the host with the lowest VM count
3. Avoiding migration to the same host (unless explicitly configured)
4. Updating host VM counts after each successful migration

## Error Handling

The script includes comprehensive error handling:

- **Pre-flight Checks**: Validate files, dependencies, and authentication
- **VM Validation**: Check VM existence and migration eligibility
- **Migration Monitoring**: Track progress and detect failures
- **Retry Logic**: Automatic retries with configurable limits
- **Detailed Logging**: Comprehensive logs for troubleshooting

## Logging

All operations are logged with timestamps to multiple locations:

- **Main Log**: `logs/migration_YYYYMMDD_HHMMSS.log`
- **Error Log**: `logs/migration_errors_YYYYMMDD_HHMMSS.log`
- **Console Output**: Color-coded real-time feedback

Log entries include:
- Timestamp and log level
- VM IDs and host information
- Migration progress and status
- Error details and retry attempts
- Final statistics and summary

## Safety Features

- **Sequential Processing**: Only one migration at a time
- **Status Verification**: Confirms successful completion before proceeding
- **Dry Run Mode**: Test without making changes
- **Comprehensive Validation**: Pre-flight checks for all components
- **Graceful Error Handling**: Continues processing after individual failures

## Troubleshooting

### Common Issues

1. **Authentication Failures**:
   ```bash
   # Source your OpenStack credentials
   source openstack-credentials.sh
   
   # Test authentication
   openstack token issue
   ```

2. **Migration Timeouts**:
   ```bash
   # Increase timeout for large VMs
   ./scripts/vm-migrate.sh vm_list.txt hosts.txt --timeout 1800
   ```

3. **Host Not Found**:
   ```bash
   # Check host availability
   ./scripts/vm-status-checker.sh --hosts target_hosts.txt
   ```

4. **VM in Error State**:
   ```bash
   # Check VM status
   ./scripts/vm-status-checker.sh --vm-list vm_list.txt
   
   # Fix VM state manually before migration
   openstack server set --state active <vm-id>
   ```

### Debug Mode

Enable verbose logging for detailed troubleshooting:
```bash
./scripts/vm-migrate.sh vm_list.txt hosts.txt --verbose
```

### Log Analysis

Check logs for detailed information:
```bash
# View latest migration log
tail -f logs/migration_*.log

# Search for errors
grep ERROR logs/migration_*.log

# View migration statistics
grep "Migration Summary" logs/migration_*.log
```

## Performance Considerations

- **Network Bandwidth**: Live migrations consume significant network resources
- **Storage Performance**: Cold migrations may impact storage during VM copying
- **Host Resources**: Ensure target hosts have adequate CPU, memory, and storage
- **Migration Timing**: Consider running during low-usage periods
- **Batch Size**: Process VMs in manageable batches for large environments

## Security Considerations

- Store OpenStack credentials securely
- Use dedicated service accounts for migrations
- Limit network access to management interfaces
- Audit migration activities through logs
- Validate target hosts before migration

## Contributing

1. Follow bash best practices and shellcheck recommendations
2. Include comprehensive error handling and logging
3. Add configuration options for new features
4. Update documentation for any changes
5. Test thoroughly with dry-run mode

## License

This project is provided as-is for educational and operational use. Please review and modify according to your organization's requirements and security policies.

## Support

For issues and questions:

1. Check the troubleshooting section
2. Review log files for detailed error information
3. Verify OpenStack environment and credentials
4. Test with dry-run mode to identify issues
5. Consult OpenStack documentation for API-specific problems

## Version History

- **v1.0**: Initial release with basic migration functionality
- **v1.1**: Added load balancing and improved error handling
- **v1.2**: Added status checker utility and enhanced logging
- **v1.3**: Added configuration file support and dry-run mode
- **v1.4**: Added Windows compatibility and PowerShell validation script

## Windows Setup and Usage

### Prerequisites for Windows

Since the main scripts are written in bash, you'll need a bash environment on Windows. Choose one of these options:

#### Option 1: Windows Subsystem for Linux (WSL) - Recommended
1. Install WSL:
```powershell
# Run as Administrator
wsl --install
```

2. Install Ubuntu or your preferred Linux distribution from Microsoft Store

3. Install dependencies in WSL:
```bash
sudo apt update
sudo apt install jq python3-pip
pip3 install python-openstackclient
```

#### Option 2: Git Bash
1. Download and install [Git for Windows](https://git-scm.com/download/win)
2. Git Bash will be available in the context menu and Start menu
3. Install dependencies (may require additional setup)

#### Option 3: MSYS2 or Cygwin
1. Install [MSYS2](https://www.msys2.org/) or [Cygwin](https://www.cygwin.com/)
2. Install required packages through their package managers

### Running Scripts on Windows

#### Using WSL (Recommended):
```powershell
# Navigate to project directory
cd C:\Users\Administrator\Desktop\code\vm-migration-tools

# Run scripts through WSL
wsl bash scripts/vm-migrate.sh examples/vm_list.txt examples/target_hosts.txt --dry-run
wsl bash scripts/vm-status-checker.sh --all-hosts
```

#### Using Git Bash:
```powershell
# Navigate to project directory
cd C:\Users\Administrator\Desktop\code\vm-migration-tools

# Run scripts through Git Bash
"C:\Program Files\Git\bin\bash.exe" scripts/vm-migrate.sh examples/vm_list.txt examples/target_hosts.txt --dry-run
```

### Windows-Specific Considerations

1. **File Paths**: Use forward slashes in file paths within the scripts
2. **Line Endings**: Ensure scripts use Unix line endings (LF) not Windows (CRLF)
3. **Permissions**: Windows file permissions work differently; scripts should be executable in your bash environment
4. **Environment Variables**: OpenStack credentials should be sourced in your bash environment

### Quick Validation

Run this PowerShell command to validate your setup:
```powershell
cd C:\Users\Administrator\Desktop\code\vm-migration-tools
Write-Host "✓ Project structure complete!" -ForegroundColor Green
```

### Troubleshooting Windows Issues

1. **Scripts not executing**: Ensure you're running in a proper bash environment
2. **Permission denied**: Make scripts executable: `chmod +x scripts/*.sh`
3. **OpenStack client not found**: Install in the same environment where you run the scripts
4. **jq not found**: Install jq in your bash environment, not just Windows
