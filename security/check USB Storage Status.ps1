# Check USB Storage Status
# Description: This script checks if USB storage is enabled on the system.
# Created by: Olamide Olaleye
# Date: 2025-03-03

$Path = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"

try {
  if (Test-Path $Path) {
    $usbStorageEnabled = (Get-ItemProperty -Path $Path -Name "Start").Start

    if ($usbStorageEnabled -eq 4) {
      Write-Output "Compliant: USB storage is disabled."
      exit 0
    }
    else {
      Write-Output "Non-Compliant: USB storage is enabled."
      exit 1
    }
  }
  else {
    Write-Output "Non-Compliant: Registry path does not exist. USB storage might be enabled."
    exit 1
  }
}
catch {
  Write-Output "Error: Unable to read registry settings. $_"
  exit 1
}
