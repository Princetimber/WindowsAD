# Check USB Storage Status
# Description: This script checks if USB storage is enabled on the system.
# Created by: Olamide Olaleye
# Date: 2025-03-03
# Version: 1.1

function Confirm-USBStorageStatus {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [string]$Path = "HKCU:\Software\Policies\Microsoft\Windows\RemovableStorageDevices"
  )
  try {
    # Check if the registry key exists
    if (-not (Test-Path -Path $Path)) {
      Write-Output "Non-Compliant"
      $hash = @{USBStorageCompliance = "Non-Compliant"; USBStorageStatus = "Enabled" }
      return $hash | ConvertTo-Json -Compress
    }

    # Get the Deny_All value
    $denyAllValue = Get-ItemProperty -Path $Path -Name "Deny_All" -ErrorAction Stop

    # Ensure exact compliance output
    if ($denyAllValue.Deny_All -eq 1) {
      Write-Output "Compliant"
      $hash = @{USBStorageCompliance = "Compliant"; USBStorageStatus = "Disabled" }
      return $hash | ConvertTo-Json -Compress
    }
    else {
      Write-Output "Non-Compliant"
      $hash = @{USBStorageCompliance = "Non-Compliant"; USBStorageStatus = "Enabled" }
      return $hash | ConvertTo-Json -Compress
    }
  }
  catch {
    Write-Output "Non-Compliant"
    $hash = @{USBStorageCompliance = "Non-Compliant"; USBStorageStatus = "Enabled" }
    return $hash | ConvertTo-Json -Compress
  }
}

# Execute the function
Confirm-USBStorageStatus