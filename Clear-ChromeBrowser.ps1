# Clear Chrome Cookies and Autofill Data Script
# This script deletes all cookies and autofill data from Google Chrome browser
# WARNING: This will permanently delete your saved cookies and autofill information

param(
    [switch]$Force,
    [switch]$WhatIf
)

# Function to write colored output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# Function to close Chrome processes
function Stop-ChromeProcesses {
    Write-ColorOutput "Checking for running Chrome processes..." "Yellow"
    
    $chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    
    if ($chromeProcesses) {
        Write-ColorOutput "Found $($chromeProcesses.Count) Chrome process(es) running." "Yellow"
        
        if ($Force -or (Read-Host "Chrome is currently running. Close it to continue? (y/N)") -eq 'y') {
            Write-ColorOutput "Stopping Chrome processes..." "Yellow"
            $chromeProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        } else {
            Write-ColorOutput "Cannot proceed while Chrome is running. Exiting." "Red"
            exit 1
        }
    } else {
        Write-ColorOutput "No Chrome processes found running." "Green"
    }
}

# Function to get Chrome user data directory
function Get-ChromeUserDataPath {
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data",
        "$env:APPDATA\Google\Chrome\User Data"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

# Function to clear cookies and autofill data
function Clear-ChromeData {
    param([string]$UserDataPath)
    
    # Files to delete for cookies and autofill
    $filesToDelete = @(
        "Default\Cookies*",
        "Default\Web Data*",
        "Default\Login Data*",
        "Profile*\Cookies*",
        "Profile*\Web Data*",
        "Profile*\Login Data*"
    )
    
    $deletedFiles = 0
    $errors = 0
    
    Write-ColorOutput "Searching for Chrome data files..." "Yellow"
    
    foreach ($filePattern in $filesToDelete) {
        $fullPath = Join-Path $UserDataPath $filePattern
        $files = Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue
        
        foreach ($file in $files) {
            try {
                if ($WhatIf) {
                    Write-ColorOutput "Would delete: $($file.FullName)" "Cyan"
                } else {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    Write-ColorOutput "Deleted: $($file.Name)" "Green"
                    $deletedFiles++
                }
            } catch {
                Write-ColorOutput "Failed to delete: $($file.Name) - $($_.Exception.Message)" "Red"
                $errors++
            }
        }
    }
    
    return @{
        DeletedFiles = $deletedFiles
        Errors = $errors
    }
}

# Main script execution
Write-ColorOutput "Chrome Data Cleaner" "Cyan"
Write-ColorOutput "===================" "Cyan"
Write-ColorOutput ""

if ($WhatIf) {
    Write-ColorOutput "Running in WhatIf mode - no files will be deleted" "Yellow"
    Write-ColorOutput ""
}

# Find Chrome user data directory
$chromeDataPath = Get-ChromeUserDataPath

if (-not $chromeDataPath) {
    Write-ColorOutput "Chrome user data directory not found!" "Red"
    Write-ColorOutput "Make sure Google Chrome is installed." "Red"
    exit 1
}

Write-ColorOutput "Found Chrome data directory: $chromeDataPath" "Green"
Write-ColorOutput ""

# Stop Chrome processes if running
if (-not $WhatIf) {
    Stop-ChromeProcesses
}

# Clear the data
Write-ColorOutput "Clearing Chrome cookies and autofill data..." "Yellow"
$result = Clear-ChromeData -UserDataPath $chromeDataPath

Write-ColorOutput ""
Write-ColorOutput "Operation completed!" "Green"

if ($WhatIf) {
    Write-ColorOutput "WhatIf mode: No files were actually deleted" "Yellow"
} else {
    Write-ColorOutput "Files deleted: $($result.DeletedFiles)" "Green"
    if ($result.Errors -gt 0) {
        Write-ColorOutput "Errors encountered: $($result.Errors)" "Red"
    }
}

Write-ColorOutput ""
Write-ColorOutput "What was cleared:" "Cyan"
Write-ColorOutput "- All cookies (login sessions, preferences)" "White"
Write-ColorOutput "- Autofill data (saved form information)" "White"
Write-ColorOutput "- Saved login credentials" "White"
Write-ColorOutput ""
Write-ColorOutput "Note: You may need to log back into websites and re-enter autofill information." "Yellow"
