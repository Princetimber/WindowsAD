# ...existing code...

function Install-ADModule {
  <#
    .SYNOPSIS
        Installs the specified Windows feature if not already installed.
    .PARAMETER ModuleName
        The name of the Windows feature to install. Defaults to 'AD-Domain-Services'.
    #>
  param(
    [Parameter(Mandatory = $false)]
    [string]$ModuleName = "AD-Domain-Services"
  )
  try {
    $feature = Get-WindowsFeature -Name $ModuleName
    if (-not $feature.Installed) {
      Write-Verbose "Installing $ModuleName module..."
      Install-WindowsFeature -Name $ModuleName -IncludeManagementTools -ErrorAction Stop
      Write-Host "$ModuleName module installed successfully."
    }
    else {
      Write-Host "$ModuleName module is already installed."
    }
  }
  catch {
    Write-Error "Failed to install $ModuleName module: $_"
  }
}

function Add-SafeModeAdministratorPassword {
  <#
    .SYNOPSIS
        Sets the Safe Mode Administrator password.
    .PARAMETER Password
        The new password as a SecureString.
    #>
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [securestring]$Password
  )
  try {
    $adminAccount = [ADSI]"WinNT://./Administrator, user"
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $adminAccount.SetPassword($plainPassword)
    $adminAccount.SetInfo()
    Write-Host "Safe Mode Administrator password set successfully."
  }
  catch {
    Write-Error "Failed to set Safe Mode Administrator password: $_"
  }
  return $SafeModeAdministratorPassword
}

function Install-ADDomainForest {
  <#
    .SYNOPSIS
        Installs a new Active Directory Domain Services forest.
    .PARAMETER DomainName
        The fully qualified domain name for the new forest.
    .PARAMETER SafeModeAdministratorPassword
        The Safe Mode Administrator password as a SecureString.
    .PARAMETER DatabasePath
        Optional. Path for the AD DS database.
    .PARAMETER LogPath
        Optional. Path for the AD DS log files.
    .PARAMETER SysvolPath
        Optional. Path for the SYSVOL folder.
    .PARAMETER DomainMode
        Optional. Domain functional level.
    .PARAMETER ForestMode
        Optional. Forest functional level.
    .PARAMETER Force
        Optional. Suppress confirmation prompts.
    #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DomainName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [securestring]$SafeModeAdministratorPassword,

    [string]$DatabasePath,
    [string]$LogPath,
    [string]$SysvolPath,
    [ValidateSet("Win2008", "Win2008R2", "Win2012", "Win2012R2", "Win2025", "Default", "WinThreshold")][string]$DomainMode = "Win2025",
    [ValidateSet("Win2008", "Win2008R2", "Win2012", "Win2012R2", "Win2025", "Default", "WinThreshold")][string]$ForestMode = "Win2025",
    [boolean]$InstallDNS,
    [string]$DomainNetbiosName,
    [switch]$Force
  )
  try {
    Install-ADModule
    if ($PSCmdlet.ShouldProcess("Install AD DS Forest for $DomainName")) {

      $params = @{
        DomainName                    = $DomainName
        SafeModeAdministratorPassword = $SafeModeAdministratorPassword
        InstallDNS                    = $InstallDNS
      }
      if ($DatabasePath) { $params.DatabasePath = $DatabasePath }
      if ($LogPath) { $params.LogPath = $LogPath }
      if ($SysvolPath) { $params.SysvolPath = $SysvolPath }
      if ($DomainMode) { $params.DomainMode = $DomainMode }
      if ($ForestMode) { $params.ForestMode = $ForestMode }
      if ($DomainNetbiosName) { $params.DomainNetbiosName = $DomainNetbiosName }
      if ($Force) { $params.Confirm = $false }

      Install-ADDSForest @params
      Write-Host "AD DS Forest installation complete."
    }
  }
  catch {
    Write-Error "Failed to install AD DS Forest: $_"
  }
}

# Example usage:
# $password = Read-Host "Enter Safe Mode Administrator Password" -AsSecureString
# Install-ADDomainForest -DomainName "corp.example.com" -InstallDNS $true -Force

# ...existing code...