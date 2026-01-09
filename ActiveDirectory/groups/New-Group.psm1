$ErrorActionPreference = 'Stop'
$Global:LogFile = "$env:TEMP\GroupManagement_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
  <#
.SYNOPSIS
Writes a message to the log file with timestamp and log level.
#>
  param(
    [Parameter(Mandatory)][string]$Message,
    [Parameter()][ValidateSet('INFO', 'DEBUG', 'WARN', 'ERROR')][string]$Level = 'INFO'
  )
  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $entry = "[$timestamp] [$Level] $Message"
  Add-Content -Path $Global:LogFile -Value $entry
  if ($Level -eq 'ERROR') { Write-Error $Message }
  elseif ($Level -eq 'WARN') { Write-Warning $Message }
  elseif ($Level -eq 'DEBUG') { Write-Verbose $Message }
  else { Write-Host $Message }
}

function Test-GroupPrerequisites {
  <#
.SYNOPSIS
Performs pre-flight checks for group creation and membership management.
#>
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )
  Write-Log "Running pre-flight checks..." 'INFO'

  # Check for AD module
  if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Log "ActiveDirectory PowerShell module is not available. Please install RSAT tools." 'ERROR'
    throw "ActiveDirectory PowerShell module is not available. Please install RSAT tools."
  }
  Write-Log "ActiveDirectory module is available." 'DEBUG'

  # Check for admin privileges
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    Write-Log "Script must be run as administrator." 'ERROR'
    throw "Script must be run as administrator."
  }
  Write-Log "Administrative privileges confirmed." 'DEBUG'

  # Simple regex for DN format
  if ($Path -notmatch '^((OU|DC)=[^,]+,)*((OU|DC)=[^,]+)$') {
    Write-Log "The Path parameter must be in the format 'OU=...,DC=...,DC=...'" 'ERROR'
    throw "The Path parameter must be in the format 'OU=...,DC=...,DC=...'"
  }
  Write-Log "Path format validated: $Path" 'DEBUG'
  Write-Log "Pre-flight checks passed." 'INFO'
}

function Test-ADModuleAndAdmin {
  <#
.SYNOPSIS
Checks AD module and admin; used for membership management
#>
  Write-Log "Running pre-flight checks for group membership update..." 'INFO'
  if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Log "ActiveDirectory PowerShell module is not available. Please install RSAT tools." 'ERROR'
    throw "ActiveDirectory PowerShell module is not available. Please install RSAT tools."
  }
  Write-Log "ActiveDirectory module is available." 'DEBUG'
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    Write-Log "Script must be run as administrator." 'ERROR'
    throw "Script must be run as administrator."
  }
  Write-Log "Administrative privileges confirmed." 'DEBUG'
  Write-Log "Pre-flight checks passed." 'INFO'
}

function New-Group {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)][ValidateNotNullOrEmpty()]
    [string]$Name,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet('Security', 'Distribution')]
    [string]$GroupCategory,
    [Parameter(Mandatory = $true)][ValidateSet('Global', 'DomainLocal', 'Universal')]
    [string]$GroupScope,
    [Parameter()][string]$DisplayName,
    [Parameter()][string]$SamAccountName,
    [Parameter()][string]$Description
  )
  Test-GroupPrerequisites -Path $Path

  Write-Log "Checking if group '$Name' exists at '$Path'..." 'INFO'
  if (Get-ADGroup -Filter "Name -eq '$Name'" -SearchBase $Path -ErrorAction SilentlyContinue) {
    Write-Log "Group '$Name' already exists." 'ERROR'
    throw "Group '$Name' already exists."
  }

  $createParams = @{
    Name          = $Name
    Path          = $Path
    GroupCategory = $GroupCategory
    GroupScope    = $GroupScope
  }
  if ($PSBoundParameters.ContainsKey('Description')) { $createParams['Description'] = $Description }
  if ($PSBoundParameters.ContainsKey('DisplayName')) { $createParams['DisplayName'] = $DisplayName }
  if ($PSBoundParameters.ContainsKey('SamAccountName')) { $createParams['SamAccountName'] = $SamAccountName }

  try {
    if ($PSCmdlet.ShouldProcess($Name, 'Create a new group')) {
      Write-Log "Creating group '$Name' in '$Path'..." 'INFO'
      $result = New-ADGroup @createParams
      Write-Log "Successfully created group '$Name'." 'INFO'
      return $result
    }
  }
  catch {
    Write-Log "Failed to create group '$Name' in '$Path'. Error: $($_.Exception.Message)" 'ERROR'
    throw "Failed to create group '$Name' in '$Path'. Error: $($_.Exception.Message)"
  }
}

function Update-ADPrincipalGroupMembership {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)][ValidateNotNullOrEmpty()]
    [string]$GroupName,
    [Parameter(Mandatory = $true)][ValidateSet('Domain Admins', 'Enterprise Admins', 'Group Policy Creator Owners', 'Schema Admins')]
    [string]$SecurityGroup,
    [Parameter(Mandatory = $true, ParameterSetName = 'Add')]
    [switch]$Add,
    [Parameter(Mandatory = $true, ParameterSetName = 'Remove')]
    [switch]$Remove
  )
  Test-ADModuleAndAdmin

  Write-Log "Validating existence of group '$GroupName' and security group '$SecurityGroup'..." 'INFO'
  $targetGroup = Get-ADGroup -Identity $SecurityGroup -ErrorAction Stop
  $memberGroup = Get-ADGroup -Identity $GroupName -ErrorAction Stop

  if ($Add.IsPresent) {
    if ($PSCmdlet.ShouldProcess($GroupName, "Add to $SecurityGroup")) {
      try {
        Write-Log "Adding group '$GroupName' to '$SecurityGroup'..." 'INFO'
        Add-ADGroupMember -Identity $targetGroup -Members $memberGroup
        Write-Log "Added '$GroupName' to '$SecurityGroup'." 'INFO'
        Write-Output "Added '$GroupName' to '$SecurityGroup'"
      }
      catch {
        Write-Log "Failed to add group '$GroupName' to '$SecurityGroup'. Error: $($_.Exception.Message)" 'ERROR'
        throw "Failed to add group '$GroupName' to '$SecurityGroup'. Error: $($_.Exception.Message)"
      }
    }
  }
  elseif ($Remove.IsPresent) {
    if ($PSCmdlet.ShouldProcess($GroupName, "Remove from $SecurityGroup")) {
      try {
        Write-Log "Removing group '$GroupName' from '$SecurityGroup'..." 'INFO'
        Remove-ADGroupMember -Identity $targetGroup -Members $memberGroup
        Write-Log "Removed '$GroupName' from '$SecurityGroup'." 'INFO'
        Write-Output "Removed '$GroupName' from '$SecurityGroup'"
      }
      catch {
        Write-Log "Failed to remove group '$GroupName' from '$SecurityGroup'. Error: $($_.Exception.Message)" 'ERROR'
        throw "Failed to remove group '$GroupName' from '$SecurityGroup'. Error: $($_.Exception.Message)"
      }
    }
  }
}