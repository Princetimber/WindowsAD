# Check USB Storage Status
# Description: This script checks if USB storage is enabled on the system.
# Created by: Olamide Olaleye
# Date: 2025-03-03
# Version: 1.0

# Check USB Storage Status
function Confirm-USBStorageStatus {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [string]$Path = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"
  )
  try {
    $usbStorageEnabled = (Get-ItemProperty -Path $Path -Name "Start").Start
    # Ensure exact compliance output
    if ($usbStorageEnabled -eq 4) {
      Write-Output "Compliant"
      $hash = @{USBStorageCompliance = "Compliant"; USBStorageStatus = "Disabled" }
      return $hash | ConvertTo-Json -Compress
      exit 0
    }
    else {
      Write-Output "Non-Compliant"
      $hash = @{USBStorageCompliance = "Non-Compliant"; USBStorageStatus = "Enabled" }
      return $hash | ConvertTo-Json -Compress
      exit 1
    }
  }
  catch {
    Write-Output "Non-Compliant"
    $hash = @{USBStorageCompliance = "Non-Compliant"; USBStorageStatus = "Enabled" }
    return $hash | ConvertTo-Json -Compress values
    exit 1
  }
}

