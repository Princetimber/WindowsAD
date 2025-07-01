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
function Install-ADDomainController {
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
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DomainName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$siteName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DomainAdministrator,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][securestring]$SafeModeAdministratorPassword,
    [string]$DatabasePath,
    [string]$LogPath,
    [string]$SysvolPath,
    [bool]$InstallDNS,
    [switch]$Force
  )
  try {
    # Check if the AD module is installed
    Install-ADModule
    # create allowed credential object
    $credential = New-Object System.Management.Automation.PSCredential($DomainAdministrator, $SafeModeAdministratorPassword)
    # Install the AD DS role
    if ($PSCmdlet.ShouldProcess("Installing additional AD Domain Controller for $DomainName in site $siteName")) {
      $params = @{
        DomainName                    = $DomainName
        SiteName                      = $siteName
        SafeModeAdministratorPassword = $SafeModeAdministratorPassword
        credential                    = $credential
        InstallDNS                    = $InstallDNS
      }
      if ($DatabasePath) { $params.DatabasePath = $DatabasePath }
      if ($LogPath) { $params.LogPath = $LogPath }
      if ($SysvolPath) { $params.SysvolPath = $SysvolPath }
      if ($DomainMode) { $params.DomainMode = $DomainMode }
      if ($Force) { $params.Confirm = $false }
    }
    Install-ADDSDomainController @params -ErrorAction Stop
    Write-Host "installed additional AD Domain Controller for $DomainName in site $siteName successfully."
  }
  catch {
    Write-Error "Failed to install additional AD Domain Controller for $DomainName in site $siteName : ${_}"
  }
}