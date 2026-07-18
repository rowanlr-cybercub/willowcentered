<#
.DESCRIPTION
This script installs ScreenConnect on endpoints. 
It's been hacked together from multiple scripts and our own code to make the most reliable installer possible and get around issues with ThreatLocker blocking the randomized MSI produced by ScreenConnect.
There is loads of output and checks because it makes it easier for me to diagnose issues in the script when working with remote endpoints.
#


.AUTHORS
John Miller - Internetek
Caleb Schmetzer - Internetek

.RESOURCES
https://www.reddit.com/r/ConnectWiseControl/comments/vwut4k/silently_deploy_the_connectwise_control_agent/
https://www.ninjaone.com/script-hub/automate-connectwise-screenconnect-deployment-with-powershell/

.OPTIONS
Action: Tells the script which action we're taking (install or uninstall)

.VARIABLES
CWScreenConnectThumbprint: Set at Global level in DRMM. Identifies the ScreenConnect instance and verifies the installer.
CWScreenConnectBaseUrl: Set at Global level in DRMM. URL of our ScreenConnect instance.
CWScreenConnectInstallerUrl: URL of the ScreenConnect installer. Set at the Client level.
CWScreenConnectusrUDF: UDF where we'll put the ScreenConnect link. Set at the Global level.
#>

$ProductName = "ScreenConnect" # Name of the software we're working with
$InstallerFile = "Internetek.ClientSetup.msi" # Generic name so we can call it in the script
$InstallerLogFile = "InstallLog.txt" # Dumps the install log so we can see what went wrong
$DownloadUrl = $env:CWScreenConnectURL # Changing specific to generic for Download-Installer function
$IsOverrideEnabled = $env:OverrideChecks -eq "True" # Converts override environ variable into a boolean
$InstallBasePath = "C:\Program Files (x86)\ScreenConnect Client ($env:CWScreenConnectThumbprint)" # Base directory path for ScreenConnect install
$ServiceName = "ScreenConnect Client ($env:CWScreenConnectThumbprint)" # Service name for ScreenConnect instance

# ==========================
# Version 6 Configuration
# ==========================

$ScriptVersion = "6.0"

$LogDirectory = "C:\ProgramData\Internetek\Logs"
$LogFile = Join-Path $LogDirectory "ScreenConnectDeploy.log"

$EnableTelegram = $true

# These are best supplied by your RMM as environment variables
$TelegramBotToken = $env:TelegramBotToken
$TelegramChatID   = $env:TelegramChatID

$ScriptStart = Get-Date

function Write-Log {

    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $Entry = "[$Time] [$Level] $Message"

    Write-Host $Entry

    Add-Content `
        -Path $LogFile `
        -Value $Entry

}

#Helper to Initialize logging
function Initialize-Logging {

    if (!(Test-Path $LogDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $LogDirectory `
            -Force | Out-Null
    }

}


Initialize-Logging

Write-Log "Logging initialized"

Write-Log "Starting script"
# === SETTING AND ENUMERATING VARIABLES === #
#Write-Log "Version 5.2" # Reported to make sure DRMM is using the current version
Write-Log "Variables received from DRMM"
Write-Log "  Thumbprint: $env:CWScreenConnectThumbprint"
Write-Log "  Base URL: $env:CWScreenConnectBaseUrl"
Write-Log "  Installer URL: $env:CWScreenConnectURL"
Write-Log "  UDF: $env:CWScreenConnectusrUDF"
Write-Log "  Action: $env:ScriptAction"
Write-Log "  Script: $PSCommandPath" # So we can find the working dir for diagnostics



# === FUNCTIONS === #
Write-Log "Setting functions"



#Telegram Function
function Send-Telegram {

    param(
        [string]$Message
    )

    if (-not $EnableTelegram) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($TelegramBotToken)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($TelegramChatID)) {
        return
    }

    try {

        $Body = @{
            chat_id    = $TelegramChatID
            text       = $Message
            #parse_mode = "MarkdownV2"
        }

        Invoke-RestMethod `
            -Method Post `
            -Uri "https://api.telegram.org/bot$TelegramBotToken/sendMessage" `
            -Body $Body `
            -TimeoutSec 60 `
            -ErrorAction Stop | Out-Null

    }
    catch {

        Write-Log "Telegram notification failed: $($_.Exception.Message)" "ERROR"

    }

}

Send-Telegram @"
🟦 ScreenConnect Deployment Started

Computer:
$env:COMPUTERNAME

User:
$env:USERNAME

Action:
$($env:ScriptAction)

Version:
$ScriptVersion

Time:
$(Get-Date)

"@


function Send-Failure {

    param([string]$Reason)

    $Elapsed = (Get-Date) - $ScriptStart

    Send-Telegram @"
🔴 ScreenConnect Deployment Failed

Computer:
$env:COMPUTERNAME

Action:
$env:ScriptAction

Reason:
$Reason

Execution:
$($Elapsed.ToString())

"@

}

function Send-Success {
    param([string]$Action)

    $Elapsed = (Get-Date) - $ScriptStart

    Send-Telegram @"
🟢 ScreenConnect $Action Successfully

Computer:
$env:COMPUTERNAME

Service:
$ServiceName

Execution:
$($Elapsed.ToString())

Time:
$(Get-Date)

"@
}


# Checks if we're working with elevated credentials
function Test-IsElevated {
    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object System.Security.Principal.WindowsPrincipal($CurrentUser)
    return $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Checks if ScreenConnect has been installed 
function Test-IsScreenConnectInstalled {
	return Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($env:CWScreenConnectThumbprint)"
}

# Stops ScreenConnect service and reports result
function Stop-SCService {
    try {
        # Get-Service | Where-Object { $_.Name -like $ServiceName }
        # $SCServices = Get-Service -Name $ServiceName
        $SCServices = Get-Service `
    -Name $ServiceName `
    -ErrorAction SilentlyContinue
        if ($SCServices) {
            $SCServices | Stop-Service -Force -ErrorAction Stop
            return $true
        } else {
            Write-Log "  No ScreenConnect Client services found."
            return $false
        }
    } catch {
        Write-Log "  Error stopping ScreenConnect services: $($_.Exception.Message)"
        return $false
    }
}

# Deletes ScreenConnect service and reports result
function Delete-SCService {
	try {
         # Get-Service | Where-Object { $_.Name -like $ServiceName }
        # $SCService = Get-Service -Name $ServiceName
        $SCServices = Get-Service `
    -Name $ServiceName `
    -ErrorAction SilentlyContinue
        if ($SCService) {
			sc.exe delete $ServiceName
            return $true
        } else {
            Write-Log "  No ScreenConnect Client services found."
            return $false
        }
    } catch {
        Write-Log "  Error deleting ScreenConnect service: $($_.Exception.Message)"
        return $false
    }
}

# Stops all processes associated with ScreenConnect
function Stop-SCProcesses {
    # Get all processes that start with "ScreenConnect"
    #Get-Process | Where-Object { $_.Name -like $ServiceName }
    $Processes = Get-Process | Where-Object { $_.Name -like "ScreenConnect*" }
    if (-not $Processes) {
        Write-Log "  No ScreenConnect processes found."
        return $true
    }

    $AllStopped = $true
    foreach ($Process in $Processes) {
        try {
            Write-Log "  Stopping process: '$($Process.Name)' (ID: $($Process.Id))"
            Stop-Process -Id $Process.Id -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 200
            if (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue) {
                Write-Log "  Process still running after Stop-Process."
                $AllStopped = $false
            }
        } catch {
            Write-Log "  Couldn't stop process: $($_.Exception.Message)"
            $AllStopped = $false
        }
    }
    return $AllStopped
}

# Creates a JoinLink in DRMM under the provided UDF
function Create-JoinLink {
    $null = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($env:CWScreenConnectThumbprint)" -Name ImagePath).ImagePath -Match '(&s=[a-f0-9\-]*)'
    $Guid = $Matches[0] -replace '&s='
    $ApiLaunchUrl= "$($env:CWScreenConnectBaseUrl)" + "Host#Access///" + $Guid + "/Join"
    New-ItemProperty -Path "HKLM:\Software\CentraStage" -Name "Custom$env:CWScreenConnectusrUDF" -PropertyType String -Value $ApiLaunchUrl -force | out-null
    Write-Log "  UDF written to UDF#$env:CWScreenConnectusrUDF."
}

# Sets the TLS version based on what the endpoint supports
function Set-TlsVersion {
	$SupportedTlsVersions = [enum]::GetValues([System.Net.SecurityProtocolType])
    if ($SupportedTlsVersions -contains [System.Net.SecurityProtocolType]::Tls13) {
        Write-Log "  Using TLS1.3"
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
		return [System.Net.SecurityProtocolType]::Tls13
    } elseif ($SupportedTlsVersions -contains [System.Net.SecurityProtocolType]::Tls12) {
        Write-Log "  Using TLS1.2"
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
		return [System.Net.SecurityProtocolType]::Tls12
    } else {
        Write-Log "TLS 1.2 or TLS 1.3 isn't supported..." "WARNING"
		return $null
    }
}

# Downloads the ScreenConnect installer
function Download-Installer {
    Write-Log "  Downloading install file"
	$PrimaryTls = Set-TlsVersion
	
    # Download the file
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerFile -TimeoutSec 60
        if (-not (Test-Path -Path $InstallerFile)) {
            throw "  File download failed"
        }
    } catch {
        Write-Log "  Download failed: $($_.Exception.Message)"
        if ($PrimaryTls -eq [System.Net.SecurityProtocolType]::Tls13) {
            Write-Log "  Retrying with TLS1.2"
            try {
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerFile -TimeoutSec 60
                if (-not (Test-Path -Path $InstallerFile)) {
                    throw "  File download failed on second attempt"
                }
            } catch {
                Write-Log "Second attempt failed: $($_.Exception.Message)" "ERROR"
                exit 1
            }
        } else {
            exit 1
        }
    }
    Write-Log "  '$InstallerFile' downloaded"
}

# Validates the installation files (for troubleshooting)
function Validate-MSI {
	param([string]$InstallerPath) 

 	Write-Log "  Validating installer file"
	if (-not (Test-Path $InstallerPath)) {
		Write-Log "  Installer file wasn't found at '$InstallerPath'"
 		return $false
	}

	$InstallerSize = (Get-Item $InstallerPath).Length
    #if ($InstallerSize -lt 1MB)
	if ($InstallerSize -lt 1MB) {
 		Write-Log "  Installer file is less than 1MB, the download has likely failed"
   		return $false
	}  	

 	Write-Log "  Installer file validated"
  	return $true
}

# Install action
function Install-ScreenConnect {
    Write-Log "Starting install"
    
	# Calling download function
    Download-Installer
 	
  	# Validating MSI
 	if (-not (Validate-MSI $InstallerFile)) {
  		Write-Log "  Installer file validation failed, exiting with error" "ERROR"
        Send-Failure "Installer validation failed"
		exit 1
	}
 	
    # Installing file
    if ($IsOverrideEnabled) {
       Write-Log "  Override called, using MSI Transform"
	#$Arguments = "/i $InstallerFile TRANSFORMS=""InstallOverride.mst"" /qn /norestart /l ""$InstallerLogFile"""
        $Arguments = "/i `"$InstallerFile`" /qn /norestart /l `"$InstallerLogFile`""
    } else {
        $Arguments = "/i `"$InstallerFile`" /qn /norestart /l `"$InstallerLogFile`""
    }
    $Process = (Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -Passthru)
    switch ($Process.ExitCode) {
        0 { Write-Log "  Install appears successful" }
        3010 { Write-Log "  Install appears successful. Reboot required to complete installation" }
        1641 { Write-Log "  Install appears successful. Installer has initiated a reboot" }
		1618 { Write-Log "  Installer cannot start. Windows Installer service is busy with another installation or update" }
  		1619 { Write-Log "  Installer cannot start. Windows Installer could not open the installation package" }
        default {
			Write-Log " Exit code: $($Process.ExitCode)"
            Write-Log "  Exit code does not indicate success, dumping log:"
            Write-Log "  +++++++++++++++++++++++++++++++++"
            Get-Content $InstallerLogFile -Tail 50 | ForEach-Object {Write-Log $_}
            Write-Log "  +++++++++++++++++++++++++++++++++"
        }
    }
	
    # Delete install file so we don't clutter up the drive
    Write-Log "Cleaning up"
    try {
        rm .\$InstallerFile -ErrorAction Stop
        Write-Log "  File deleted"
    } catch {
        Write-Log "Failed to delete file: $($_.Exception.Message)" "ERROR"
    }
	
    if (($Process.ExitCode -ne 0) -and ($Process.ExitCode -ne 3010)) {
        Write-Log "Install appears to have failed, exiting script"
        exit 1
    }
	
    # Make sure it started
    Write-Log "Checking install success"
	
    # Get service status
    Write-Log "  Getting Service status"
    $StartService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    #if ($StartService.length -gt 0)
    if ($null -ne $StartService) {
        if ($StartService.Status -eq 'Running') {
            Write-Log "  Service exists and is started"
        } else {
            Write-Log "  Service exists but is not started, attempting to start service"
            Start-Service $ServiceName
        }
		
		# Writing link to DRRM UDF
        Write-Log "Creating link in UDF"
        Create-JoinLink

        $Elapsed = (Get-Date) - $ScriptStart

        Send-Telegram @"
        🟢 ScreenConnect Installed Successfully

        Computer:
        $env:COMPUTERNAME

        Service:
        $ServiceName

        Status:
        Running

        Execution:
        $($Elapsed.ToString())

"@
    } else {
        Write-Log "  Service doesn't exist, exiting script with error"
        exit 1
    }
}



# Uninstall action
function Uninstall-ScreenConnect {
    Write-Log "Starting uninstall"
    Write-Log "  Stopping $ServiceName service"

    # Stopping service and processes, supposed to help with uninstall
    if (Stop-SCService) {
        Write-Log "  Service has stopped"
    } else { 
        Write-Log "  Service is still running"
    }
	
	Write-Log "  Deleting $ServiceName service"
	
	if (Delete-SCService) {
		Write-Log "  Service has been deleted"
	} else { 
        Write-Log "  Service was not deleted"
    }

	Write-Log "  Stopping ScreenConnect processes"
	
    if (Stop-SCProcesses) {
        Write-Log "  Processes have stopped"
    } else {
        Write-Log "  One or more processes failed to stop"
    }

    $UninstallCompleted = $false

    # Attempt uninstall using Method #1
    Write-Log "  Attempting registry string uninstall"

    $UninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($Path in $UninstallPaths) {
        Get-ChildItem $Path -ErrorAction SilentlyContinue | ForEach-Object {
            $App = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($App.DisplayName -like $ServiceName -and $App.UninstallString) {
                Write-Log "  Found: $($App.DisplayName)"
                Write-Log "  Uninstalling using the registry string: $($App.UninstallString)"
                $UninstallString = $App.UninstallString.Trim()

                $Parts = $UninstallString -split '\s+', 2
                $ExePath = $Parts[0]
                $Arguments = if ($Parts.Count -ge 2) { $Parts[1] } else { "" }

                # Resolve executable path from path if necessary
                $Command = Get-Command $ExePath -ErrorAction SilentlyContinue
                if ($Command) {
                    $ExePath = $Command.Source
                } else {
                    Write-Log "  Warning: executable '$ExePath' not found in path, skipping"
                    continue
                }

                # Add silent flags
                if ($ExePath -match 'msiexec.exe') {
                    if ($Arguments -notmatch "/quiet|/qn|/s|/silent") {
                        $Arguments += " /qn /norestart"
                    }
                } else {
                    if ($Arguments -notmatch "/quiet|/qn|/s|/silent") {
                        $Arguments += " /quiet"
                    }
                }

                Write-Log "  Executing uninstall: '$ExePath $Arguments'"
                try {
                    Start-Process -FilePath $ExePath -ArgumentList $Arguments -Wait -ErrorAction Stop
                    Write-Log "  Registry uninstall command executed"
                } catch {
                    Write-Log "  Registry uninstall failed: $($_.Exception.Message)"
                }

                Start-Sleep -Seconds 5

                if (-not (Test-IsScreenConnectInstalled)) {
                    Write-Log "  Uninstall was successful using registry string method"
                    $UninstallCompleted = $true
                    break
                } else {
                    Write-Log "  ScreenConnect still installed, trying next path"
                }
            }
        }

        if ($UninstallCompleted) { break }
    }

    # Attempt uninstall using Method #2
    if (-not $UninstallCompleted) {
        Write-Log "  Attempting Get-Package uninstall"
        try {
            $Packages = Get-Package | Where-Object { $_.Name -like $ServiceName }
            foreach ($Package in $Packages) {
                Write-Log "  Attempting to uninstall package: $($Package.Name)"
                $Package | Uninstall-Package -ErrorAction Stop | Out-Null
                Write-Log "    Successfully uninstalled $($Package.Name)"
            }
        } catch {
            Write-Log "  Get-Package uninstall failed: $($_.Exception.Message)"
        }

        Start-Sleep -Seconds 5

        if (-not (Test-IsScreenConnectInstalled)) {
            Write-Log "  Uninstall was successful using the Get-Package method"
            $UninstallCompleted = $true
        } else {
            Write-Log "  ScreenConnect still installed after Get-Package uninstall"
        }
    }

    $IsInstalled = Test-IsScreenConnectInstalled
    if ($IsInstalled) {
        Write-Log "  Uninstall appears unsuccessful"
        # Restarting service so we can log in if needed but hiding it so it doesn't clutter the log
        $Arguments = "/c Start-Service `"$ServiceName`""
        $Process = Start-Process -Wait cmd -ArgumentList $Arguments -PassThru
		exit 1
    } else {
        Write-Log "  Uninstall appears successful"

        $Elapsed = (Get-Date) - $ScriptStart

        Send-Telegram @"
        🟢 ScreenConnect Uninstalled Successfully

        Computer:
        $env:COMPUTERNAME

        Service:
        $ServiceName

        Execution:
        $($Elapsed.ToString())

"@
    }
}

# === PREFLIGHT CHECKS === #
if ($IsOverrideEnabled) {
    Write-Log "Skipping preflight checks"
} else {
    Write-Log "Starting preflight checks"
    # Make sure we're working with elevated rights
    if (-not (Test-IsElevated)) {
        Write-Log "  Not Admin. Please run with Administrator privileges"
        exit 1
    } else {
        Write-Log "  Elevated privs confirmed, continuing script"
    }

    # Make sure we can write and delete
    try {
        $TestWrite = New-Item -Path "test.txt" -ItemType File -ErrorAction SilentlyContinue # Hiding output to not clutter the screen
        $TestWrite = rm test.txt -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "  Unable to write or delete in the target directory, exiting script"
        exit 1
    }
    
	Write-Log "  Able to write and delete in target directory, continuing script"

    # Check if ScreenConnect already installed, using service instead of uninstall because we care more about files on drive
    $IsInstalled = Test-IsScreenConnectInstalled
    if ($IsInstalled) {
        Write-Log "  '$ProductName' is installed"
    } else {
        Write-Log "  '$ProductName' is not installed"
    }
    
	Write-Log "  Preflight Checks completed"
}

# === ACTIONS === #
Write-Log "Starting action"
switch ($env:ScriptAction) {
    "install" {
        if ($IsInstalled -and -not $IsOverrideEnabled) {
            Write-Log "  '$ProductName' already installed, nothing to do"
        } else {
            Install-ScreenConnect
        }
    }
    "uninstall" {
        if ($IsInstalled -or $IsOverrideEnabled) {
            Uninstall-ScreenConnect
        } else {
            Write-Log "  '$ProductName' not installed, nothing to do"
        }
    }
    default {
        Write-Log "No valid action provided, exiting script"
		exit 1
    }
}

$Elapsed = (Get-Date) - $ScriptStart

Write-Log "Execution Time: $($Elapsed.ToString())"

Write-Log "Script completed successfully"