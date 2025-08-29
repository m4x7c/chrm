# Clear Chrome Autofill Cache and Passwords Script
# This script will close all Chrome processes and delete autofill/password data

Write-Host "Chrome Data Cleaner Script" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green

# Function to close Chrome processes
function Close-ChromeProcesses {
    Write-Host "`nClosing Chrome processes..." -ForegroundColor Yellow
    
    $chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    
    if ($chromeProcesses) {
        Write-Host "Found $($chromeProcesses.Count) Chrome process(es). Closing them..." -ForegroundColor Yellow
        
        # First try graceful shutdown
        $chromeProcesses | ForEach-Object {
            try {
                $_.CloseMainWindow() | Out-Null
            } catch {
                Write-Warning "Could not gracefully close Chrome process $($_.Id)"
            }
        }
        
        # Wait a moment for graceful shutdown
        Start-Sleep -Seconds 3
        
        # Force kill any remaining processes
        $remainingProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
        if ($remainingProcesses) {
            Write-Host "Force closing remaining Chrome processes..." -ForegroundColor Red
            $remainingProcesses | Stop-Process -Force
        }
        
        # Wait for processes to fully terminate
        Start-Sleep -Seconds 2
        Write-Host "Chrome processes closed successfully." -ForegroundColor Green
    } else {
        Write-Host "No Chrome processes found running." -ForegroundColor Green
    }
}

# Function to get Chrome user data directory
function Get-ChromeUserDataPath {
    $defaultPath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    
    if (Test-Path $defaultPath) {
        return $defaultPath
    } else {
        Write-Error "Chrome user data directory not found at: $defaultPath"
        return $null
    }
}

# Function to delete autofill and password data
function Clear-ChromeData {
    param(
        [string]$UserDataPath
    )
    
    if (-not $UserDataPath) {
        Write-Error "Chrome user data path is required"
        return
    }
    
    Write-Host "`nClearing Chrome autofill and password data..." -ForegroundColor Yellow
    
    # Files and folders to delete for autofill and passwords
    $dataToDelete = @(
        "Default\Web Data",           # Autofill data
        "Default\Web Data-journal",   # Autofill journal
        "Default\Login Data",         # Saved passwords
        "Default\Login Data-journal", # Password journal
        "Default\Preferences"         # May contain autofill preferences
    )
    
    $deletedCount = 0
    
    foreach ($item in $dataToDelete) {
        $fullPath = Join-Path $UserDataPath $item
        
        if (Test-Path $fullPath) {
            try {
                if ((Get-Item $fullPath).PSIsContainer) {
                    Remove-Item $fullPath -Recurse -Force
                } else {
                    Remove-Item $fullPath -Force
                }
                Write-Host "Deleted: $item" -ForegroundColor Green
                $deletedCount++
            } catch {
                Write-Warning "Failed to delete: $item - $($_.Exception.Message)"
            }
        } else {
            Write-Host "Not found: $item" -ForegroundColor Gray
        }
    }
    
    if ($deletedCount -gt 0) {
        Write-Host "`nSuccessfully deleted $deletedCount data file(s)." -ForegroundColor Green
    } else {
        Write-Host "`nNo data files were found to delete." -ForegroundColor Yellow
    }
}

# Main execution
try {
    # Confirm action with user
    Write-Host "This script will:" -ForegroundColor Cyan
    Write-Host "1. Close all Chrome browser windows" -ForegroundColor Cyan
    Write-Host "2. Delete Chrome autofill cache data" -ForegroundColor Cyan
    Write-Host "3. Delete Chrome saved passwords" -ForegroundColor Cyan
    Write-Host ""
    Write-Warning "This action cannot be undone!"
    
    $confirmation = Read-Host "Do you want to continue? (y/N)"
    
    if ($confirmation -eq 'y' -or $confirmation -eq 'Y' -or $confirmation -eq 'yes') {
        # Close Chrome processes
        Close-ChromeProcesses
        
        # Get Chrome user data path
        $chromeDataPath = Get-ChromeUserDataPath
        
        if ($chromeDataPath) {
            # Clear the data
            Clear-ChromeData -UserDataPath $chromeDataPath
            
            Write-Host "`nOperation completed successfully!" -ForegroundColor Green
            Write-Host "Chrome autofill cache and passwords have been cleared." -ForegroundColor Green
            Write-Host "`nNote: You may need to sign in to your accounts again when you restart Chrome." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
} finally {
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
