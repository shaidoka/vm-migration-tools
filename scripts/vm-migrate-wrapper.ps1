# VM Migration Tools - PowerShell Wrapper
# This script provides an easy way to run the bash migration scripts on Windows

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("migrate", "status", "validate")]
    [string]$Action,
    
    [string]$VmListFile = "examples\vm_list.txt",
    [string]$HostsFile = "examples\target_hosts.txt",
    [string]$ConfigFile = "",
    [switch]$DryRun,
    [switch]$VerboseOutput,
    [switch]$AllHosts,
    [switch]$Summary,
    [int]$MaxRetries = 3,
    [int]$Timeout = 600
)

# Find bash environment
$bashCommand = ""

# Check for WSL
try {
    $wslInfo = wsl --list --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        $bashCommand = "wsl bash"
        Write-Host "Using WSL bash environment" -ForegroundColor Green
    }
} catch {
    # WSL not available
}

# Check for Git Bash if WSL not found
if (-not $bashCommand) {
    $gitBashPaths = @(
        "${env:ProgramFiles}\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "${env:LOCALAPPDATA}\Programs\Git\bin\bash.exe"
    )
    
    foreach ($path in $gitBashPaths) {
        if (Test-Path $path) {
            $bashCommand = "`"$path`""
            Write-Host "Using Git Bash: $path" -ForegroundColor Green
            break
        }
    }
}

if (-not $bashCommand) {
    Write-Host "ERROR: No bash environment found!" -ForegroundColor Red
    Write-Host "Please install WSL or Git for Windows" -ForegroundColor Yellow
    exit 1
}

# Build command based on action
$scriptCommand = ""

switch ($Action) {
    "migrate" {
        $scriptCommand = "scripts/vm-migrate.sh $VmListFile $HostsFile"
          if ($ConfigFile) { $scriptCommand += " --config $ConfigFile" }
        if ($DryRun) { $scriptCommand += " --dry-run" }
        if ($VerboseOutput) { $scriptCommand += " --verbose" }
        if ($MaxRetries -ne 3) { $scriptCommand += " --max-retries $MaxRetries" }
        if ($Timeout -ne 600) { $scriptCommand += " --timeout $Timeout" }
    }
    
    "status" {
        $scriptCommand = "scripts/vm-status-checker.sh"
        
        if ($VmListFile -and (Test-Path $VmListFile)) { $scriptCommand += " --vm-list $VmListFile" }
        if ($HostsFile -and (Test-Path $HostsFile)) { $scriptCommand += " --hosts $HostsFile" }
        if ($AllHosts) { $scriptCommand += " --all-hosts" }
        if ($Summary) { $scriptCommand += " --summary" }
    }
    
    "validate" {
        $scriptCommand = "scripts/setup-validator.sh"
    }
}

# Execute the command
Write-Host "Executing: $bashCommand $scriptCommand" -ForegroundColor Cyan
Write-Host ""

$fullCommand = "$bashCommand $scriptCommand"
Invoke-Expression $fullCommand
