<#
.SYNOPSIS
  The function New-ADDomainController installs a new Active Directory Domain Controller in an existing domain.
.DESCRIPTION
  The function New-ADDomainController installs a new Active Directory Domain Controller in an existing domain.
.PARAMETER DomainName
  The FQDN of the domain to join.
.PARAMETER SiteName
  The name of the site in which to create the new domain controller.
.PARAMETER DatabasePath
  The path to the directory where the AD DS database is stored. This defaults to the value of '$env:SystemDrive\Windows\'. if the parameter is not specified. I strongly recommend that you use a separate disk for the database.
.PARAMETER LogPath
  The path to the directory where the AD DS log files are stored. This defaults to the value of '$env:SystemDrive\Windows\NTDS\'. if the parameter is not specified. I strongly recommend that you use a separate disk for the log files.
.PARAMETER SysvolPath
  The path to the directory where the AD DS system volume (SYSVOL) is stored. This defaults to the value of '$env:SystemDrive\Windows\'. if the parameter is not specified. I strongly recommend that you use a separate disk for the SYSVOL.
.PARAMETER DomainAdministratorUserName
  The name of the domain administrator user account used for the installation.
.PARAMETER KeyVaultName
  The name of the Key Vault to use.
.PARAMETER ResourceGroupName
  The name of the resource group to use where the Key Vault is located.
.PARAMETER SafeAdministratorSecretName
  The name of the secret in the Key Vault that contains the password for the Safe Mode Administrator Password.
.PARAMETER AllowedDomainAdministratorSecretName
  The name of the secret in the Key Vault that contains the password for the adminstrator used for the installation.
.EXAMPLE
  New-ADDomainController -DomainName 'contoso.com' -DatabasePath 'C:\' -LogPath 'C:\' -SysvolPath 'C:\' -DomainAdministratorUserName 'contoso\administrator' -KeyVaultName 'contoso-kv' -ResourceGroupName 'contoso-rg' -SafeAdministratorSecretName 'SafeModeAdministratorPassword' -AllowedDomainAdministratorSecretName 'AllowedDomainAdministratorPassword'
.NOTES
The function requires the following PowerShell version:
- PowerShell 7.1.3 or later. Please refer to the following article for more information:
- https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1
The function requires the following modules to be installed:
- Microsoft.PowerShell.SecretManagement
- az.keyVault
Please refer to the following articles for more information:
- https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/?view=powershell-7.1
The function will register the Key Vault as a secret vault:
- It will retrieve the Safe Mode Administrator Password from the Key Vault.
- It will retrieve the password for the domain administrator user account used for the installation from the Key Vault.
The function will install the following Windows features:
- AD-Domain-Services.
This function assumes that you have already created a Key Vault and that you have already created a secret in the Key Vault that contains the password for the Safe Mode Administrator Password.
The scripts sets the error action preference to 'Stop' and the confirm preference to 'Low'. Please refer to the following articles for more information:
- https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7.1
- https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters?view=powershell-7.1
#>
function New-ADDomainController {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$DomainName,
    [string]$SiteName = 'Default-First-Site-Name',
    [Parameter(Mandatory = $false)]
    [string]$DatabasePath = "$env:SystemDrive\Windows\",
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:SystemDrive\Windows\NTDS\",
    [Parameter(Mandatory = $false)]
    [string]$SysvolPath = "$env:SystemDrive\Windows\",
    [Parameter(Mandatory = $true)]
    [string]$DomainAdministratorUserName,
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$SafeAdministratorSecretName,
    [Parameter(Mandatory = $true)]
    [string]$AllowedDomainAdministratorSecretName
  )
  $ErrorActionPreference = 'Stop'
  $ConfirmPreference = 'Low'

  $path = @($DatabasePath, $LogPath, $SysvolPath)
  $path | ForEach-Object {
    if (-not (Test-Path -Path $_)) {
      Write-Error "Path $_ does not exist. Please create it first, and then rerun this script.: $_"
      exit 1
    }
  }

  $env:LOG_PATH = Join-Path -Path $logPath -ChildPath 'logs'
  $env:DATABASE_PATH = Join-Path -Path $databasePath -ChildPath 'ntds'
  $env:SYSVOL_PATH = Join-Path -Path $sysvolPath -ChildPath 'SYSVOL'

  $InstallParams = @{
    InstallDNS   = $true
    Force        = $true
    DomainName   = $DomainName
    SiteName     = $SiteName
    DatabasePath = $env:DATABASE_PATH
    LogPath      = $env:LOG_PATH
    SysvolPath   = $env:SYSVOL_PATH
  }

  $moduleNames = @('Microsoft.PowerShell.SecretManagement', 'az.keyVault')
  $moduleNames | ForEach-Object {
    if (-not (Get-Module -ListAvailable -Name $_)) {
      Install-PSResource -Name $_ -Repository PSGallery -Scope AllUsers -TrustRepository -PassThru -Confirm:$false
    }
  }
  $moduleNames | ForEach-Object -Parallel { Import-Module -Name $_ }

  try {
    Connect-AzAccount -UseDeviceAuthentication
    $vaultName = (Get-AzKeyVault -ResourceGroupName $resourceGroupName -Name $keyVaultName).VaultName
    $subscriptionId = (Get-AzContext).Subscription.Id
    Register-SecretVault -ModuleName az.keyVault -Name $vaultName -VaultParameters @{AZKVaultName = $vaultName; SubscriptionID = $subscriptionId }
    $safeModeAdministratorPassword = Get-Secret -Vault $vaultName -Name $safeAdministratorSecretName
    $allowedDomainAdministratorPassword = Get-Secret -Vault $vaultName -Name $allowedDomainAdministratorSecretName
    $InstallParams['SafeModeAdministratorPassword'] = $safeModeAdministratorPassword
    $InstallParams['Credential'] = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $domainAdministratorUserName, $allowedDomainAdministratorPassword
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

    Install-ADDSDomainController @InstallParams
  }
  catch {
    Write-Error "Failed to create a new Active Directory domain controller. Please try again.: $_"
    exit 1
  }
  finally {
    Unregister-SecretVault -Name $vaultName
    Disconnect-AzAccount
    $ConfirmPreference = 'Medium'
    $ErrorActionPreference = 'Stop'
  }
}
