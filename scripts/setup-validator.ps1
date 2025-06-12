# VM Migration Tools Setup Validator (PowerShell Version)
# 
# This script validates the setup and dependencies for the VM migration tools on Windows

# Colors for output (limited PowerShell support)
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    switch ($Color) {
        "Red" { Write-Host $Message -ForegroundColor Red }
        "Green" { Write-Host $Message -ForegroundColor Green }
        "Yellow" { Write-Host $Message -ForegroundColor Yellow }
        "Blue" { Write-Host $Message -ForegroundColor Blue }
        "Cyan" { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

Write-ColorOutput "=== VM Migration Tools Setup Validator ===" "Blue"
Write-Host ""

# Check script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-ColorOutput "Project Structure Check:" "Blue"

# Check required directories
$RequiredDirs = @("scripts", "config", "examples", "logs", ".github", ".vscode")
foreach ($dir in $RequiredDirs) {
    $dirPath = Join-Path $ProjectRoot $dir
    if (Test-Path $dirPath -PathType Container) {
        Write-ColorOutput "  ✓ $dir/ directory exists" "Green"
    } else {
        Write-ColorOutput "  ✗ $dir/ directory missing" "Red"
    }
}

Write-Host ""

# Check required files
Write-ColorOutput "Required Files Check:" "Blue"
$RequiredFiles = @(
    "scripts/vm-migrate.sh",
    "scripts/vm-status-checker.sh",
    "config/migration.conf",
    "examples/vm_list.txt",
    "examples/target_hosts.txt",
    "README.md",
    ".github/copilot-instructions.md"
)

foreach ($file in $RequiredFiles) {
    $filePath = Join-Path $ProjectRoot $file
    if (Test-Path $filePath -PathType Leaf) {
        Write-ColorOutput "  ✓ $file exists" "Green"
    } else {
        Write-ColorOutput "  ✗ $file missing" "Red"
    }
}

Write-Host ""

# Check for Windows Subsystem for Linux (WSL) or Git Bash
Write-ColorOutput "Bash Environment Check:" "Blue"
$bashAvailable = $false

# Check for WSL
try {
    $wslInfo = wsl --list --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "  ✓ WSL is available" "Green"
        $bashAvailable = $true
    }
} catch {
    # WSL not available
}

# Check for Git Bash
$gitBashPaths = @(
    "${env:ProgramFiles}\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "${env:LOCALAPPDATA}\Programs\Git\bin\bash.exe"
)

foreach ($path in $gitBashPaths) {
    if (Test-Path $path) {
        Write-ColorOutput "  ✓ Git Bash found at: $path" "Green"
        $bashAvailable = $true
        break
    }
}

if (-not $bashAvailable) {
    Write-ColorOutput "  ⚠ No bash environment found" "Yellow"
    Write-ColorOutput "    Install options:" "Yellow"
    Write-ColorOutput "    1. Windows Subsystem for Linux (WSL)" "Yellow"
    Write-ColorOutput "    2. Git for Windows (includes Git Bash)" "Yellow"
    Write-ColorOutput "    3. Cygwin or MSYS2" "Yellow"
}

Write-Host ""

# Check dependencies (if available)
Write-ColorOutput "Dependencies Check:" "Blue"
$Dependencies = @("jq", "openstack")

foreach ($dep in $Dependencies) {
    try {
        $command = Get-Command $dep -ErrorAction SilentlyContinue
        if ($command) {
            Write-ColorOutput "  ✓ $dep is available" "Green"
        } else {
            Write-ColorOutput "  ✗ $dep is not available" "Red"
            switch ($dep) {
                "jq" {
                    Write-ColorOutput "    Install via: winget install stedolan.jq" "Yellow"
                    Write-ColorOutput "    Or download from: https://stedolan.github.io/jq/" "Yellow"
                }
                "openstack" {
                    Write-ColorOutput "    Install via: pip install python-openstackclient" "Yellow"
                }
            }
        }
    } catch {
        Write-ColorOutput "  ✗ $dep is not available" "Red"
    }
}

Write-Host ""

# Check Python and pip
Write-ColorOutput "Python Environment Check:" "Blue"
try {
    $pythonVersion = python --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "  ✓ Python is installed: $pythonVersion" "Green"
        
        # Check pip
        $pipVersion = pip --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  ✓ pip is available" "Green"
        } else {
            Write-ColorOutput "  ⚠ pip is not available" "Yellow"
        }
    } else {
        Write-ColorOutput "  ✗ Python is not installed" "Red"
        Write-ColorOutput "    Install from: https://python.org" "Yellow"
    }
} catch {
    Write-ColorOutput "  ✗ Python is not available" "Red"
}

Write-Host ""

# Configuration check
Write-ColorOutput "Configuration Check:" "Blue"
$configFile = Join-Path $ProjectRoot "config/migration.conf"
if (Test-Path $configFile) {
    Write-ColorOutput "  ✓ Configuration file exists" "Green"
} else {
    Write-ColorOutput "  ✗ Configuration file missing" "Red"
}

Write-Host ""

# Examples check
Write-ColorOutput "Examples Check:" "Blue"
$ExampleFiles = @("examples/vm_list.txt", "examples/target_hosts.txt")
foreach ($example in $ExampleFiles) {
    $examplePath = Join-Path $ProjectRoot $example
    if (Test-Path $examplePath) {
        $content = Get-Content $examplePath | Where-Object { $_ -notmatch '^#' -and $_ -notmatch '^\s*$' }
        $lineCount = $content.Count
        Write-ColorOutput "  ✓ $example exists ($lineCount example entries)" "Green"
    } else {
        Write-ColorOutput "  ✗ $example missing" "Red"
    }
}

Write-Host ""

# Final recommendations
Write-ColorOutput "=== Setup Summary ===" "Blue"
Write-ColorOutput "Windows-specific recommendations:" "Cyan"
Write-ColorOutput "1. Install WSL or Git Bash for running the bash scripts" "Yellow"
Write-ColorOutput "2. Install Python and pip for OpenStack client" "Yellow"
Write-ColorOutput "3. Install jq for JSON processing" "Yellow"
Write-ColorOutput "4. Update examples with your actual VM IDs and hosts" "Yellow"
Write-ColorOutput "5. Configure OpenStack credentials" "Yellow"

Write-Host ""
Write-ColorOutput "To run the scripts on Windows:" "Cyan"
Write-ColorOutput "Option 1 (WSL): wsl bash scripts/vm-migrate.sh ..." "Blue"
Write-ColorOutput "Option 2 (Git Bash): 'C:\Program Files\Git\bin\bash.exe' scripts/vm-migrate.sh ..." "Blue"

Write-Host ""
Write-ColorOutput "Setup validation complete!" "Green"
