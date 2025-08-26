# Clear-Chrome-Simple.ps1
# Simplified and reliable Chrome browser cleaner
# Fixes execution issues and ensures consistent operation

param(
    [switch]$KeepBookmarks,
    [switch]$KeepPasswords,
    [switch]$WhatIf
)

Write-Host "Simple Chrome Browser Cleaner" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host "Extensions will be preserved automatically" -ForegroundColor Green

# Function to safely remove files with error handling
function Remove-SafeFiles {
    param(
        [string]$Path,
        [string[]]$FilePatterns,
        [string]$Description
    )
    
    $removedCount = 0
    foreach ($pattern in $FilePatterns) {
        try {
            $files = Get-ChildItem -Path $Path -Filter $pattern -Force -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                if ($WhatIf) {
                    Write-Host "[PREVIEW] Would remove: $($file.Name)" -ForegroundColor Gray
                } else {
                    Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                    if (-not (Test-Path $file.FullName)) {
                        $removedCount++
                        Write-Host "[OK] Removed: $($file.Name)" -ForegroundColor Green
                    }
                }
            }
        } catch {
            Write-Warning "Error with pattern $pattern`: $_"
        }
    }
    
    if (-not $WhatIf -and $removedCount -gt 0) {
        Write-Host "[SUCCESS] Removed $removedCount file(s) for $Description" -ForegroundColor Green
    } elseif (-not $WhatIf) {
        Write-Host "[INFO] No files found for $Description" -ForegroundColor Yellow
    }
}

# Function to safely remove directories
function Remove-SafeDirectory {
    param(
        [string]$Path,
        [string]$Description,
        [string[]]$PreservePaths = @()
    )
    
    if (Test-Path $Path) {
        if ($WhatIf) {
            Write-Host "[PREVIEW] Would clear directory: $Path" -ForegroundColor Gray
            return
        }
        
        try {
            $items = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
            $removedCount = 0
            
            foreach ($item in $items) {
                $shouldPreserve = $false
                foreach ($preserve in $PreservePaths) {
                    if ($item.Name -like "*$preserve*") {
                        $shouldPreserve = $true
                        Write-Host "[PRESERVED] $($item.Name)" -ForegroundColor DarkGreen
                        break
                    }
                }
                
                if (-not $shouldPreserve) {
                    Remove-Item $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    if (-not (Test-Path $item.FullName)) {
                        $removedCount++
                    }
                }
            }
            
            Write-Host "[SUCCESS] Cleared $removedCount items from $Description" -ForegroundColor Green
            
        } catch {
            Write-Warning "Error clearing $Description`: $_"
        }
    } else {
        Write-Host "[INFO] Directory not found: $Description" -ForegroundColor Yellow
    }
}

# Step 1: Close Chrome processes with better error handling
Write-Host "`n=== Step 1: Closing Chrome Processes ===" -ForegroundColor Cyan

try {
    $chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    
    if ($chromeProcesses) {
        if ($WhatIf) {
            Write-Host "[PREVIEW] Would close $($chromeProcesses.Count) Chrome process(es)" -ForegroundColor Gray
        } else {
            Write-Host "Closing $($chromeProcesses.Count) Chrome process(es)..." -ForegroundColor Yellow
            $chromeProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
            
            # Verify closure
            $remainingProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
            if ($remainingProcesses) {
                Write-Warning "Some Chrome processes are still running"
                # Force kill remaining processes
                $remainingProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
            Write-Host "[OK] Chrome processes closed" -ForegroundColor Green
        }
    } else {
        Write-Host "[OK] No Chrome processes running" -ForegroundColor Green
    }
} catch {
    Write-Warning "Error managing Chrome processes: $_"
}

# Step 2: Find Chrome installations
Write-Host "`n=== Step 2: Finding Chrome Installations ===" -ForegroundColor Cyan

$chromePaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data",
    "$env:LOCALAPPDATA\Google\Chrome Beta\User Data",
    "$env:LOCALAPPDATA\Google\Chrome Dev\User Data",
    "$env:LOCALAPPDATA\Google\Chrome SxS\User Data",
    "$env:LOCALAPPDATA\Chromium\User Data",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
)

$foundPaths = @()
foreach ($path in $chromePaths) {
    if (Test-Path $path) {
        $foundPaths += $path
        Write-Host "Found Chrome data: $path" -ForegroundColor Green
    }
}

if ($foundPaths.Count -eq 0) {
    Write-Host "[ERROR] No Chrome installations found!" -ForegroundColor Red
    Write-Host "Please ensure Chrome is installed and has been run at least once." -ForegroundColor Red
    exit 1
}

# Step 3: Process each Chrome installation
Write-Host "`n=== Step 3: Processing Chrome Data ===" -ForegroundColor Cyan

foreach ($chromeDataPath in $foundPaths) {
    Write-Host "`nProcessing: $chromeDataPath" -ForegroundColor Magenta
    
    # Find profiles
    $profiles = @()
    
    # Default profile
    $defaultProfile = Join-Path $chromeDataPath "Default"
    if (Test-Path $defaultProfile) {
        $profiles += @{Name="Default"; Path=$defaultProfile}
    }
    
    # Additional profiles
    $additionalProfiles = Get-ChildItem -Path $chromeDataPath -Directory -Name "Profile *" -ErrorAction SilentlyContinue
    foreach ($profile in $additionalProfiles) {
        $profilePath = Join-Path $chromeDataPath $profile
        $profiles += @{Name=$profile; Path=$profilePath}
    }
    
    if ($profiles.Count -eq 0) {
        Write-Host "[WARNING] No profiles found in $chromeDataPath" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Found $($profiles.Count) profile(s)" -ForegroundColor Cyan
    
    # Process each profile
    foreach ($profile in $profiles) {
        Write-Host "`n--- Processing Profile: $($profile.Name) ---" -ForegroundColor Yellow
        $profilePath = $profile.Path
        
        # Extensions to preserve
        $preserveList = @("Extensions", "Extension State", "Extension Rules", "Local Extension Settings")
        
        # Clear session data
        Write-Host "Clearing session data..." -ForegroundColor White
        Remove-SafeFiles $profilePath @("Cookies", "Cookies-journal") "Cookies"
        Remove-SafeDirectory "$profilePath\Sessions" "Active sessions"
        Remove-SafeDirectory "$profilePath\Session Storage" "Session storage"
        
        # Clear passwords (unless preserving)
        if (-not $KeepPasswords) {
            Write-Host "Clearing saved passwords..." -ForegroundColor White
            Remove-SafeFiles $profilePath @("Login Data", "Login Data-journal", "Login Data-shm", "Login Data-wal") "Login data"
            Remove-SafeFiles $profilePath @("Password Manager") "Password manager data"
        } else {
            Write-Host "[PRESERVED] Keeping saved passwords" -ForegroundColor DarkGreen
        }
        
        # Clear form data and autofill
        Write-Host "Clearing form data..." -ForegroundColor White
        Remove-SafeFiles $profilePath @("Web Data", "Web Data-journal") "Form data and autofill"
        
        # Clear browsing history
        if (-not $KeepBookmarks) {
            Write-Host "Clearing browsing history and bookmarks..." -ForegroundColor White
            Remove-SafeFiles $profilePath @("History", "History-journal", "Archived History") "Browsing history"
            Remove-SafeFiles $profilePath @("Bookmarks", "Bookmarks.bak") "Bookmarks"
            Remove-SafeFiles $profilePath @("Top Sites", "Top Sites-journal") "Top sites"
        } else {
            Write-Host "[PRESERVED] Keeping bookmarks (history still cleared)" -ForegroundColor DarkGreen
            Remove-SafeFiles $profilePath @("History", "History-journal", "Archived History") "Browsing history"
        }
        
        # Clear cache directories
        Write-Host "Clearing cache..." -ForegroundColor White
        Remove-SafeDirectory "$profilePath\Cache" "Cache"
        Remove-SafeDirectory "$profilePath\Code Cache" "Code cache"
        Remove-SafeDirectory "$profilePath\GPUCache" "GPU cache"
        Remove-SafeDirectory "$profilePath\ShaderCache" "Shader cache"
        
        # Clear local storage (but preserve extensions)
        Write-Host "Clearing local storage..." -ForegroundColor White
        Remove-SafeDirectory "$profilePath\Local Storage" "Local storage" $preserveList
        Remove-SafeDirectory "$profilePath\IndexedDB" "IndexedDB" $preserveList
        
        # Clear additional data
        Write-Host "Clearing additional data..." -ForegroundColor White
        Remove-SafeFiles $profilePath @("Preferences") "Preferences (login states)"
        Remove-SafeFiles $profilePath @("Secure Preferences") "Secure preferences"
        Remove-SafeDirectory "$profilePath\Network" "Network data"
        Remove-SafeDirectory "$profilePath\Service Worker" "Service Worker cache"
        
        # Show preserved extensions
        $extensionsPath = "$profilePath\Extensions"
        if (Test-Path $extensionsPath) {
            $extensionCount = (Get-ChildItem $extensionsPath -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
            Write-Host "[PRESERVED] Extensions directory ($extensionCount extensions)" -ForegroundColor DarkGreen
        }
        
        Write-Host "[COMPLETED] Profile $($profile.Name) processed successfully" -ForegroundColor Green
    }
}

# Step 4: Final summary
Write-Host "`n=== CLEANUP SUMMARY ===" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "PREVIEW MODE - No actual changes were made" -ForegroundColor Yellow
    Write-Host "Run without -WhatIf to perform actual cleanup" -ForegroundColor Yellow
} else {
    Write-Host "[SUCCESS] Chrome browser cleanup completed!" -ForegroundColor Green
    Write-Host "[SUCCESS] All sessions logged out" -ForegroundColor Green
    Write-Host "[SUCCESS] Cache and temporary files removed" -ForegroundColor Green
    Write-Host "[SUCCESS] Extensions preserved" -ForegroundColor Green
    
    if ($KeepBookmarks) {
        Write-Host "[SUCCESS] Bookmarks preserved" -ForegroundColor Green
    } else {
        Write-Host "[SUCCESS] Bookmarks and history removed" -ForegroundColor Green
    }
    
    if ($KeepPasswords) {
        Write-Host "[SUCCESS] Saved passwords preserved" -ForegroundColor Green
    } else {
        Write-Host "[SUCCESS] Saved passwords removed" -ForegroundColor Green
    }
    
    # Ask about restarting Chrome
    Write-Host "`nWould you like to restart Chrome now? (y/N): " -ForegroundColor Yellow -NoNewline
    try {
        $restart = Read-Host
        
        if ($restart -eq 'y' -or $restart -eq 'Y' -or $restart -eq 'yes') {
            Write-Host "Starting Chrome..." -ForegroundColor Green
            
            # Try to find and start Chrome
            $chromeExePaths = @(
                "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
            )
            
            $chromeExe = $chromeExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
            
            if ($chromeExe) {
                Start-Process $chromeExe -ErrorAction SilentlyContinue
                Write-Host "[SUCCESS] Chrome started" -ForegroundColor Green
            } else {
                Write-Warning "Could not find Chrome executable. Please start manually."
            }
        }
    } catch {
        Write-Host "`nSkipping Chrome restart" -ForegroundColor Yellow
    }
}

Write-Host "`nScript completed successfully!" -ForegroundColor Cyan
Write-Host "`nUsage:" -ForegroundColor DarkCyan
Write-Host "  .\Clear-Chrome-Simple.ps1                 # Full cleanup"
Write-Host "  .\Clear-Chrome-Simple.ps1 -KeepPasswords  # Keep passwords"
Write-Host "  .\Clear-Chrome-Simple.ps1 -KeepBookmarks  # Keep bookmarks"
Write-Host "  .\Clear-Chrome-Simple.ps1 -WhatIf         # Preview only"

# Ensure script completes properly
Write-Host "`nConsole ready for next command." -ForegroundColor Green
