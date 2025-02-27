<#
.SYNOPSIS
  This script checks if a device has consumed a specific device configuration policy.
.DESCRIPTION
  This function checks if the specified device configuration policy is applied to the given device.
.PARAMETER GroupName
  The name of the group to which the policy is assigned.
.PARAMETER PolicyName
  The name of the device configuration policy.
.PARAMETER DeviceName
  The name of the device to check.
.NOTES
  File Name      : DevicePolicyStatus.ps1
  Author         : Olamide Olaleye
  Prerequisite   : PowerShell 7.4.6 or later
  Modules        : Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement, Microsoft.Graph.Groups
  Date           : 2025-02-18
  Version        : 1.0
  Change History : 1.0 - Initial version
.LINK
  Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
  Confirm-DeviceConsumedPolicy -GroupName "All Devices" -PolicyName "Windows 10 Enterprise" -DeviceName "Device1"
  This example checks if the device "Device1" has consumed the policy "Windows 10 Enterprise" assigned to the group "All Devices".
#>
$ErrorActionPreference = "Stop"

# Check if running in PowerShell 7+
if ($PSVersionTable.PSEdition -ne "Core") {
  Write-Error "This script requires PowerShell 7 or later. Please run it in PowerShell 7+."
  exit 1
}
# Install and Import Required Modules
function Install-RequiredModule {
  [CmdletBinding()]
  param(
    [string[]]$Modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.DeviceManagement", "Microsoft.Graph.Groups")
  )
  $Modules | ForEach-Object -Process {
    if (-not (Get-Module -Name $_ -ListAvailable)) {
      Set-PSResourceRepository -Name PSGallery -InstallationPolicy Trusted
      Install-PSResource -Name $_ -Repository PSGallery -Scope CurrentUser -Confirm:$false
    }
  }
  $Modules | ForEach-Object -Process {
    Import-Module -Name $_ -Force
  }
}
# Connect to Microsoft Graph with configurable authentication method
function Connect-ToGraph {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)][ValidateSet('DeviceCode', 'Interactive', 'AppRegistration')][string]$AuthMethod = 'DeviceCode',
    [Parameter(Mandatory = $false)][string[]]$Scopes = @("DeviceManagementConfiguration.Read.All", "DeviceManagementManagedDevices.Read.All", "Group.Read.All")
  )
  try {
    if ($null -eq $Global:GraphConnection) {
      try {
        switch ($AuthMethod) {
          'DeviceCode' {
            Connect-MgGraph -Scopes $Scopes -UseDeviceCode -NoWelcome
          }
          'Interactive' {
            Connect-MgGraph -Scopes $Scopes -NoWelcome
          }
          'AppRegistration' {
            Write-Error "App Registration Authentication method is not supported by this script."
            return
          }
        }
        $timeout = New-TimeSpan -Seconds 120
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        while ($stopwatch.Elapsed -lt $timeout) {
          $context = (Get-MgContext -ErrorAction SilentlyContinue).Account
          $Global:GraphConnection = $context
          if ($context) {
            Write-Output "Connected to Microsoft Graph as $($context)."
            break
          }
          else {
            Write-Output "Already connected to Microsoft Graph."
          }
        }
      }
      catch {
        Write-Error "Failed to connect to Microsoft Graph. Please see the error message for details.: $_"
        throw
      }
    }
  }
  catch {
    Write-Error "An unexpected error occurred: $_"
    throw
  }
}


function Disconnect-FromGraph {
  try {
    if ($Global:GraphConnection) {
      Disconnect-MgGraph
      $Global:GraphConnection = $null
      Write-Output "Disconnected from Microsoft Graph."
    }
  }
  catch {
    Write-Error "Failed to disconnect from Microsoft Graph: $_"
    throw
  }
}

# Get the group ID(s) for the specified group name(s)
function Get-DeviceGroupId {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$GroupName
  )
  try {
    $groupId = Get-MgGroup -Filter "displayName in ('$($GroupName -join "','")" -All | Select-Object -ExpandProperty Id
    if (-not $groupId) {
      throw "No groups found with the specified name(s)."
    }
    return $groupId
  }
  catch {
    Write-Error "Failed to retrieve group IDs: $_"
    throw
  }
}

# Get the device configuration policy ID for the specified policy name
function Get-DeviceConfigurationPolicyId {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$PolicyName
  )
  try {
    $policyId = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$PolicyName'" -All | Select-Object -ExpandProperty Id
    if (-not $policyId) {
      throw "No policy found with the specified name."
    }
    return $policyId
  }
  catch {
    Write-Error "Failed to retrieve policy ID: $_"
    throw
  }
}

# Check if the policy is assigned to the specified group(s)
function Get-DeviceConfigurationPolicyAssignment {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$PolicyId,
    [Parameter(Mandatory = $true)]
    [string[]]$GroupId
  )
  try {
    $assignments = Get-MgDeviceManagementDeviceConfigurationAssignment -DeviceConfigurationId $PolicyId -All | Where-Object { $GroupId -contains $_.Target.GroupId }
    if ($assignments) {
      Write-Output "The policy $PolicyId is assigned to the group(s): $($GroupId -join ', ')"
    }
    else {
      Write-Output "The policy $PolicyId is NOT assigned to the group(s): $($GroupId -join ', ')"
    }
    return $assignments
  }
  catch {
    Write-Error "Failed to retrieve policy assignments: $_"
    throw
  }
}

# Main function to confirm if the device has consumed the policy
function Confirm-DevicePolicyStatus {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$PolicyName,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$GroupName,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$DeviceName,
    [Parameter(Mandatory = $false)][ValidateSet('DeviceCode', 'Interactive', 'AppRegistration')][string]$AuthMethod = 'DeviceCode',
    [Parameter(Mandatory = $false)][string[]]$Scopes = @("DeviceManagementConfiguration.Read.All", "DeviceManagementManagedDevices.Read.All", "Group.Read.All"),
    [Parameter(Mandatory = $false)]
    [string]$OutputFile = (Join-Path -Path $env:USERPROFILE\Documents\ -ChildPath "DevicePolicyStatus.txt")
  )
  try {
    # Install and import required modules
    Install-RequiredModule
    # Connect to Microsoft Graph
    Connect-ToGraph -AuthMethod $AuthMethod
    # Retrieve policy ID
    $policyId = Get-DeviceConfigurationPolicyId -PolicyName $PolicyName
    # Initialize an array to store results
    $results = @()
    # Check device status for each device
    foreach ($device in $DeviceName) {
      Write-Output "`nChecking the device: $device"
      $deviceStatus = Get-MgDeviceManagementDeviceConfigurationDeviceStatus -DeviceConfigurationId $policyId -All | Where-Object { $_.DeviceDisplayName -eq $device }
      if ($deviceStatus) {
        $status = $deviceStatus.Status | Select-Object -First 1
        $lastReportedDateTime = $deviceStatus.LastReportedDateTime | Select-Object -First 1
      }
      else {
        $status = "Not Found"
        $lastReportedDateTime = "N/A"
      }
      # Add the result to the array
      $results += [PSCustomObject]@{
        "DeviceName"    = $deviceStatus.DeviceDisplayName | Select-Object -First 1
        "Policy Status" = $status
        "Last Reported" = $lastReportedDateTime
      }
    }
    # Output the results as a table
    $results | Format-Table -AutoSize -Property DeviceName, 'Policy Status', 'Last Reported' | Out-File -FilePath $OutputFile -Append -Encoding utf8 -Force


  }
  catch {
    Write-Error "An error occurred: $_"
  }
  finally {
    Write-Output "`nResults saved to: $OutputFile"
  }
}