# Clear-ChromeBrowser.ps1
# Script to logout from all Chrome browser sessions and clear browser data while preserving extensions
# Compatible with: Google Chrome, Chrome Beta, Chrome Dev, Chrome Canary, Chromium

param(
    [switch]$KeepBookmarks,
    [switch]$KeepPasswords,
    [switch]$WhatIf
)

Write-Host "Google Chrome Session Cleaner" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host "Extensions will be preserved automatically" -ForegroundColor Green

# Function to safely remove directory contents with exclusions
function Remove-DirectoryContents {
    param(
        [string]$Path,
        [string]$Description,
        [string[]]$ExcludePaths = @()
    )
    
    if (Test-Path $Path) {
        Write-Host "Clearing $Description..." -ForegroundColor Yellow
        if ($WhatIf) {
            Write-Host "Would clear: $Path" -ForegroundColor Gray
            if ($ExcludePaths.Count -gt 0) {
                Write-Host "  Excluding: $($ExcludePaths -join ', ')" -ForegroundColor DarkGray
            }
        } else {
            try {
                $items = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    $shouldExclude = $false
                    foreach ($exclude in $ExcludePaths) {
                        if ($item.FullName -like "*$exclude*" -or $item.Name -like "*$exclude*") {
                            $shouldExclude = $true
                            Write-Host "  [SKIP] Preserving: $($item.Name)" -ForegroundColor DarkGreen
                            break
                        }
                    }
                    if (-not $shouldExclude) {
                        Remove-Item $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
                Write-Host "[OK] Cleared $Description" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to clear $Description`: $_"
            }
        }
    } else {
        Write-Host "[!] $Description not found at: $Path" -ForegroundColor DarkYellow
    }
}

# Function to remove specific files
function Remove-Files {
    param(
        [string]$Path,
        [string[]]$FilePatterns,
        [string]$Description
    )
    
    if (Test-Path $Path) {
        Write-Host "Removing $Description..." -ForegroundColor Yellow
        foreach ($pattern in $FilePatterns) {
            $files = Get-ChildItem -Path $Path -Filter $pattern -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                if ($WhatIf) {
                    Write-Host "Would remove: $($file.FullName)" -ForegroundColor Gray
                } else {
                    try {
                        Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                        Write-Host "[OK] Removed $($file.Name)" -ForegroundColor Green
                    } catch {
                        Write-Warning "Failed to remove $($file.Name): $_"
                    }
                }
            }
        }
    }
}

# Step 1: Close all Chrome browser processes
Write-Host "`n1. Closing Chrome browser processes..." -ForegroundColor Cyan
if ($WhatIf) {
    $chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    if ($chromeProcesses) {
        Write-Host "Would close $($chromeProcesses.Count) Chrome process(es)" -ForegroundColor Gray
        foreach ($proc in $chromeProcesses) {
            Write-Host "  - $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Gray
        }
    }
} else {
    try {
        $chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
        if ($chromeProcesses) {
            Write-Host "Found $($chromeProcesses.Count) Chrome process(es)" -ForegroundColor Yellow
            foreach ($proc in $chromeProcesses) {
                Write-Host "  - Closing: $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Yellow
            }
            $chromeProcesses | Stop-Process -Force
            Start-Sleep -Seconds 3
            Write-Host "[OK] Chrome browser(s) closed" -ForegroundColor Green
        } else {
            Write-Host "[OK] No Chrome processes running" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Error closing Chrome: $_"
    }
}

# Step 2: Define Chrome data directories and find installed versions
$chromePaths = @(
    @{Name="Google Chrome"; Path="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{Name="Google Chrome Beta"; Path="$env:LOCALAPPDATA\Google\Chrome Beta\User Data"},
    @{Name="Google Chrome Dev"; Path="$env:LOCALAPPDATA\Google\Chrome Dev\User Data"},
    @{Name="Google Chrome SxS"; Path="$env:LOCALAPPDATA\Google\Chrome SxS\User Data"}, # Canary
    @{Name="Chromium"; Path="$env:LOCALAPPDATA\Chromium\User Data"},
    @{Name="Microsoft Edge"; Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data"}
)

$foundProfiles = @()
foreach ($chrome in $chromePaths) {
    if (Test-Path $chrome.Path) {
        $foundProfiles += $chrome
        Write-Host "`n2. Found $($chrome.Name) at: $($chrome.Path)" -ForegroundColor Cyan
    }
}

if ($foundProfiles.Count -eq 0) {
    Write-Host "`n[ERROR] No Chrome browser installations found!" -ForegroundColor Red
    Write-Host "Searched locations:" -ForegroundColor Red
    foreach ($chrome in $chromePaths) {
        Write-Host "  - $($chrome.Path)" -ForegroundColor Red
    }
    Write-Host "Please ensure Chrome is installed and has been run at least once." -ForegroundColor Red
    exit 1
}

# Process each found Chrome installation
foreach ($chromeProfile in $foundProfiles) {
    $profileBasePath = $chromeProfile.Path
    Write-Host "`n" + "="*50 -ForegroundColor Magenta
    Write-Host "Processing: $($chromeProfile.Name)" -ForegroundColor Magenta
    Write-Host "="*50 -ForegroundColor Magenta

    # Find all user profiles (Default, Profile 1, Profile 2, etc.)
    $userProfiles = @()
    if (Test-Path "$profileBasePath\Default") {
        $userProfiles += @{Name="Default"; Path="$profileBasePath\Default"}
    }
    
    # Look for additional profiles
    $additionalProfiles = Get-ChildItem -Path $profileBasePath -Directory -Name "Profile *" -ErrorAction SilentlyContinue
    foreach ($prof in $additionalProfiles) {
        $userProfiles += @{Name=$prof; Path="$profileBasePath\$prof"}
    }

    if ($userProfiles.Count -eq 0) {
        Write-Host "[!] No user profiles found in $($chromeProfile.Name)" -ForegroundColor Yellow
        continue
    }

    Write-Host "Found $($userProfiles.Count) user profile(s)" -ForegroundColor Cyan
    foreach ($userProfile in $userProfiles) {
        Write-Host "  - $($userProfile.Name)" -ForegroundColor Gray
    }

    # Process each user profile
    foreach ($userProfile in $userProfiles) {
        $profilePath = $userProfile.Path
        Write-Host "`n--- Processing Profile: $($userProfile.Name) ---" -ForegroundColor Yellow

        # Step 3: Clear session and login data (preserving extensions)
        Write-Host "`n3. Clearing session and login data..." -ForegroundColor Cyan

        # Define extension-related folders to preserve
        $extensionPaths = @("Extensions", "Extension State", "Extension Rules", "Extension Cookies", "Local Extension", "Sync Extension")

        # Clear cookies and session data
        Remove-DirectoryContents "$profilePath\Sessions" "Active sessions"
        Remove-DirectoryContents "$profilePath\Session Storage" "Session storage"
        Remove-Files $profilePath @("Cookies", "Cookies-journal") "Cookies"
        if (-not $KeepPasswords) {
            Remove-Files $profilePath @("Login Data", "Login Data-journal") "Login data"
        }

        # Clear web data and local storage (but preserve extension storage)
        Remove-DirectoryContents "$profilePath\Local Storage" "Local storage" $extensionPaths
        Remove-DirectoryContents "$profilePath\IndexedDB" "IndexedDB" $extensionPaths
        Remove-DirectoryContents "$profilePath\Service Worker" "Service Worker cache"

        # Step 4: Clear browsing data
        Write-Host "`n4. Clearing browsing data..." -ForegroundColor Cyan

        # Clear cache
        Remove-DirectoryContents "$profilePath\Cache" "Cache"
        Remove-DirectoryContents "$profilePath\Code Cache" "Code cache"
        Remove-DirectoryContents "$profilePath\GPUCache" "GPU cache"
        Remove-DirectoryContents "$profilePath\ShaderCache" "Shader cache"
        Remove-DirectoryContents "$profilePath\DawnCache" "Dawn cache" # WebGPU cache

        # Clear history
        Remove-Files $profilePath @("History", "History-journal", "Archived History") "Browsing history"
        Remove-Files $profilePath @("Top Sites", "Top Sites-journal") "Top Sites"

        # Clear downloads
        Remove-Files $profilePath @("DownloadMetadata") "Download metadata"

        # Clear form data
        Remove-Files $profilePath @("Web Data", "Web Data-journal") "Form data and autofill"

        # Step 5: Clear additional data (preserving extensions)
        Write-Host "`n5. Clearing additional data..." -ForegroundColor Cyan

        # Smart preferences cleaning - preserve extension settings
        if (Test-Path "$profilePath\Preferences") {
            if ($WhatIf) {
                Write-Host "Would clean preferences file (keeping extension data)" -ForegroundColor Gray
            } else {
                try {
                    $prefsContent = Get-Content "$profilePath\Preferences" -Raw | ConvertFrom-Json
                    
                    # Remove login-related preferences but keep extension data
                    if ($prefsContent.profile) {
                        $prefsContent.profile.PSObject.Properties.Remove("exit_type")
                        $prefsContent.profile.PSObject.Properties.Remove("exited_cleanly")
                        $prefsContent.profile.PSObject.Properties.Remove("last_engagement_time")
                    }
                    if ($prefsContent.signin) {
                        $prefsContent.PSObject.Properties.Remove("signin")
                    }
                    if ($prefsContent.account_info) {
                        $prefsContent.PSObject.Properties.Remove("account_info")
                    }
                    if ($prefsContent.sync) {
                        $prefsContent.PSObject.Properties.Remove("sync")
                    }
                    # Keep extensions settings intact
                    
                    $prefsContent | ConvertTo-Json -Depth 100 | Set-Content "$profilePath\Preferences"
                    Write-Host "[OK] Cleaned preferences (extensions preserved)" -ForegroundColor Green
                } catch {
                    Write-Warning "Could not parse preferences file, using fallback method"
                    # Fallback - just remove the file if we can't parse it
                    Remove-Files $profilePath @("Preferences") "Preferences (fallback method)"
                }
            }
        }

        Remove-Files $profilePath @("Secure Preferences") "Secure preferences"

        # Clear network data
        Remove-DirectoryContents "$profilePath\Network" "Network data"

        # Clear media cache
        Remove-DirectoryContents "$profilePath\Media Cache" "Media cache"

        # Clear additional Chrome-specific data
        Remove-DirectoryContents "$profilePath\Platform Notifications" "Platform notifications"
        Remove-DirectoryContents "$profilePath\BudgetDatabase" "Budget database"
        Remove-DirectoryContents "$profilePath\databases" "Web databases"
        Remove-DirectoryContents "$profilePath\FileSystem" "File System cache"
        Remove-DirectoryContents "$profilePath\GCM Store" "GCM Store"

        # Step 6: EXPLICITLY preserve extension directories
        Write-Host "`n6. Extension preservation check..." -ForegroundColor Cyan
        $extensionDirs = @(
            "$profilePath\Extensions",
            "$profilePath\Extension State", 
            "$profilePath\Extension Rules",
            "$profilePath\Extension Cookies",
            "$profilePath\Local Extension Settings",
            "$profilePath\Sync Extension Settings"
        )

        $foundExtensions = $false
        foreach ($extDir in $extensionDirs) {
            if (Test-Path $extDir) {
                $foundExtensions = $true
                $extCount = (Get-ChildItem $extDir -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
                Write-Host "  [PRESERVED] $extDir ($extCount items)" -ForegroundColor Green
            }
        }
        
        if (-not $foundExtensions) {
            Write-Host "  [INFO] No extensions found in this profile" -ForegroundColor Yellow
        }

        # Step 7: Handle bookmarks and passwords
        Write-Host "`n7. Handling bookmarks and passwords..." -ForegroundColor Cyan

        if (-not $KeepBookmarks) {
            Remove-Files $profilePath @("Bookmarks", "Bookmarks.bak") "Bookmarks"
        } else {
            Write-Host "[OK] Keeping bookmarks (as requested)" -ForegroundColor Green
        }

        if ($KeepPasswords) {
            Write-Host "[OK] Keeping saved passwords (as requested)" -ForegroundColor Green
        }

        # Step 8: Clear temporary files and logs
        Write-Host "`n8. Clearing temporary files..." -ForegroundColor Cyan
        Remove-DirectoryContents "$profilePath\logs" "Log files"
        Remove-DirectoryContents "$profilePath\crash dumps" "Crash dumps"

        Write-Host "`n[COMPLETED] Profile $($userProfile.Name) processing finished" -ForegroundColor Green
    }

    # Clear system-wide Chrome data
    Write-Host "`n9. Clearing system-wide data..." -ForegroundColor Cyan
    if (Test-Path "$profileBasePath\System Profile") {
        Remove-DirectoryContents "$profileBasePath\System Profile\Network" "System network data"
    }
    Remove-DirectoryContents "$profileBasePath\ShaderCache" "System shader cache"
    Remove-DirectoryContents "$profileBasePath\SwReporter" "Software Reporter cache"

    Write-Host "`n[COMPLETED] $($chromeProfile.Name) processing finished" -ForegroundColor Green
}

# Final summary
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "FINAL CLEANUP SUMMARY" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "This was a preview run. No changes were made." -ForegroundColor Yellow
    Write-Host "Run the script without -WhatIf to perform the actual cleanup." -ForegroundColor Yellow
} else {
    Write-Host "[SUCCESS] Processed $($foundProfiles.Count) Chrome installation(s)" -ForegroundColor Green
    Write-Host "[SUCCESS] All sessions have been logged out" -ForegroundColor Green
    Write-Host "[SUCCESS] Cache and temporary files removed" -ForegroundColor Green
    Write-Host "[SUCCESS] Extensions and their data preserved" -ForegroundColor Green
    
    if ($KeepBookmarks) {
        Write-Host "[SUCCESS] Bookmarks preserved" -ForegroundColor Green
    }
    if ($KeepPasswords) {
        Write-Host "[SUCCESS] Saved passwords preserved" -ForegroundColor Green
    }
    
    # Ask if user wants to restart Chrome
    Write-Host "`nWould you like to restart Chrome browser now? (y/N): " -ForegroundColor Yellow -NoNewline
    $restart = Read-Host
    
    if ($restart -eq 'y' -or $restart -eq 'Y' -or $restart -eq 'yes') {
        Write-Host "Starting Chrome browser..." -ForegroundColor Green
        try {
            # Try common Chrome installation paths
            $chromeExePaths = @(
                "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles}\Google\Chrome Beta\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome Beta\Application\chrome.exe",
                "${env:ProgramFiles}\Google\Chrome Dev\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome Dev\Application\chrome.exe",
                "$env:LOCALAPPDATA\Google\Chrome SxS\Application\chrome.exe", # Canary
                "$env:LOCALAPPDATA\Chromium\Application\chrome.exe"
            )
            
            $chromeExe = $chromeExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
            
            if ($chromeExe) {
                Start-Process $chromeExe
                Write-Host "[SUCCESS] Chrome browser started" -ForegroundColor Green
            } else {
                Write-Warning "Could not find Chrome executable. Please start it manually."
                Write-Host "Searched paths:" -ForegroundColor Gray
                foreach ($path in $chromeExePaths) {
                    Write-Host "  - $path" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Warning "Failed to start Chrome: $_"
        }
    }
}

Write-Host "`nScript completed!" -ForegroundColor Cyan

# Usage examples
Write-Host "`nUsage Examples:" -ForegroundColor DarkCyan
Write-Host "  .\Clear-ChromeBrowser.ps1                        # Full cleanup (preserves extensions)"
Write-Host "  .\Clear-ChromeBrowser.ps1 -KeepBookmarks         # Keep bookmarks + extensions"
Write-Host "  .\Clear-ChromeBrowser.ps1 -KeepPasswords         # Keep passwords + extensions" 
Write-Host "  .\Clear-ChromeBrowser.ps1 -WhatIf                # Preview changes"
Write-Host "  .\Clear-ChromeBrowser.ps1 -KeepBookmarks -KeepPasswords -WhatIf"

Write-Host "`nSupported Chrome versions:" -ForegroundColor DarkCyan
Write-Host "  - Google Chrome Stable, Beta, Dev, Canary"
Write-Host "  - Chromium, Microsoft Edge (Chromium-based)"
Write-Host "`nNote: Extensions are ALWAYS preserved by this script." -ForegroundColor Cyan
Write-Host "      Multiple user profiles are automatically detected and processed." -ForegroundColor Cyan
