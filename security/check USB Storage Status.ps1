# Check USB Storage Status
# Description: This script checks if USB storage is enabled on the system.
# Created by: Olamide Olaleye
# Date: 2025-03-03
# Version: 1.0

# Check USB Storage Status
$Path = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"
$usbStorageEnabled = (Get-ItemProperty -Path $Path -Name "Start").Start
# Ensure exact compliance output
if ($usbStorageEnabled -eq 4) {
    Write-Output "Compliant"
    exit 0
} else {
    Write-Output "Non-Compliant"
    exit 1
}

