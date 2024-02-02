<#
.SYNOPSIS
  The function New-ADDomain installs a new Active Directory domain in Azure or on-premises.
.DESCRIPTION
  The function New-ADDomain installs a new Active Directory domain in Azure or on-premises.
  It will install all the prerequisites, create a new Active Directory domain, and promote the server to a domain controller.
.PARAMETER DomainName
  The FQDN of the domain to create.
.PARAMETER DomainNetBIOSName
  The NetBIOS name of the domain to create.
.PARAMETER DomainMode
  The domain functional level of the domain to create. This defaults to the value of the 'WinThreshold'
.PARAMETER ForestMode
  The forest functional level of the domain to create.This defaults to the value of the 'WinThreshold'.
.PARAMETER DatabasePath
  The path to the directory where the AD DS database is stored. This defaults to the value of '$env:SystemDrive\Windows\'. if the parameter is not specified. I strongly recommend that you use a separate disk for the database.
.PARAMETER LogPath
  The path to the directory where the AD DS log files are stored. This defaults to the value of '$env:SystemDrive\Windows\NTDS\'. if the parameter is not specified. I strongly recommend that you use a separate disk for the log files.
.PARAMETER SysvolPath
  The path to the directory where the AD DS system volume (SYSVOL) is stored. This defaults to the value of '$env:SystemDrive\Windows\'. if the parameter is not specified. I strongly recommend that you use a separate disk for the SYSVOL.
.PARAMETER KeyVaultName
  The name of the Key Vault to use.
.PARAMETER ResourceGroupName
  The name of the resource group to use where the Key Vault is located.
.PARAMETER SecretName
  The name of the secret in the Key Vault that contains the password for the Safe Mode Administrator Password.This defaults to the value of 'safeModeAdministratorPassword'.
.EXAMPLE
  New-ADDomain -domainName "contoso.com" -domainNetBIOSName "CONTOSO" -databasePath "D:\" -logPath "D:\" -sysvolPath "E:\" -keyVaultName "contoso-keyvault" -resourceGroupName "contoso-rg" -safeModeAdministratorPassword "contoso-safeModeAdministratorPassword"
.NOTES
  This script requires the following PowerShell version:
  - PowerShell 7.1.3 or later. Please refer to the following article for more information:
    - https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1
This script requires the following PowerShell modules:
  - Microsoft.PowerShell.SecretManagement
  - az.keyVault
  Please refer to the following articles for more information:
  - https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/?view=powershell-7.1
This script will install the following Windows features:
  - AD-Domain-Services
This script will register the Key Vault as a secret vault.
This script will retrieve the Safe Mode Administrator Password from the Key Vault.
This script assumes that you have already created a Key Vault and that you have already created a secret in the Key Vault that contains the password for the Safe Mode Administrator Password.
This script uses an error action preference of 'Stop' and a confirm preference of 'Low'. Please refer to the following articles for more information:
  - https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7.1
  - https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters?view=powershell-7.1
#>
function New-ADDomain {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string]$DomainName,
    [Parameter(Mandatory = $true)]
    [string]$DomainNetBiosName,
    [Parameter(Mandatory = $false)]
    [string]$DomainMode = "WinThreshold",
    [Parameter(Mandatory = $false)]
    [string]$ForestMode = "WinThreshold",
    [Parameter(Mandatory = $false)]
    [string]$DatabasePath = "$env:SystemDrive\Windows\",
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:SystemDrive\Windows\NTDS\",
    [Parameter(Mandatory = $false)]
    [string]$SysvolPath = "$env:SystemDrive\Windows\",
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$secretName = "safeModeAdministratorPassword"
  )
  $ErrorActionPreference = 'Stop'
  try {
    if($PSCmdlet.ShouldProcess($DomainName,'Create a new Active Directory domain')){
      $path = @($DatabasePath, $LogPath, $SysvolPath)
      $path | ForEach-Object {
        if (-not (Test-Path -Path $_)) {
          throw "The path does not exist. Please try again.: $_"
        }
      }

      $env:LOG_PATH = Join-Path -Path $LogPath -ChildPath 'logs'
      $env:DATABASE_PATH = Join-Path -Path $DatabasePath -ChildPath 'ntds'
      $env:SYSVOL_PATH = Join-Path -Path $SysvolPath -ChildPath 'SYSVOL'

      $InstallParams = @{
        InstallDNS           = $true
        NoRebootOnCompletion = $false
        Force                = $true
        DomainName           = $DomainName
        DomainNetBiosName    = $DomainNetBiosName
        DomainMode           = $DomainMode
        ForestMode           = $ForestMode
        DatabasePath         = $env:DATABASE_PATH
        LogPath              = $env:LOG_PATH
        SysvolPath           = $env:SYSVOL_PATH
      }

      $moduleNames = @('Microsoft.PowerShell.SecretManagement', 'az.keyVault')
      $moduleNames | ForEach-Object {
        if (-not (Get-Module -ListAvailable -Name $_)) {
          Install-PSResource -Name $_ -Repository PSGallery -Scope AllUsers -TrustRepository -PassThru -Confirm:$false
        }
      }

      $moduleNames | ForEach-Object -Parallel { Import-Module -Name $_ }

      Connect-AzAccount -UseDeviceAuthentication
      Start-Sleep -Seconds 90

      $vaultName = (Get-AzKeyVault -ResourceGroupName $ResourceGroupName -Name $KeyVaultName).VaultName
      $subscriptionId = (Get-AzContext).Subscription.Id

      $vaultParameters = @{
        AZKVaultName   = $vaultName
        SubscriptionID = $subscriptionId
      }

      Register-SecretVault -ModuleName az.keyVault -Name $vaultName -VaultParameters $vaultParameters -Confirm:$false
      $safeModeAdministratorPassword = Get-Secret -Vault $vaultName -Name $secretName

      $InstallParams['SafeModeAdministratorPassword'] = $safeModeAdministratorPassword

      Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

      Install-ADDSForest @InstallParams
    }
    elseif($PSCmdlet.ShouldContinue("Do you want to continue with creating a new Active Directory domain named $DomainName?", "Creating a new Active Directory domain named '$DomainName'")){ 
      $path = @($DatabasePath, $LogPath, $SysvolPath)
      $path | ForEach-Object {
        if (-not (Test-Path -Path $_)) {
          throw "The path does not exist. Please try again.: $_"
        }
      }

      $env:LOG_PATH = Join-Path -Path $LogPath -ChildPath 'logs'
      $env:DATABASE_PATH = Join-Path -Path $DatabasePath -ChildPath 'ntds'
      $env:SYSVOL_PATH = Join-Path -Path $SysvolPath -ChildPath 'SYSVOL'

      $InstallParams = @{
        InstallDNS           = $true
        NoRebootOnCompletion = $false
        Force                = $true
        DomainName           = $DomainName
        DomainNetBiosName    = $DomainNetBiosName
        DomainMode           = $DomainMode
        ForestMode           = $ForestMode
        DatabasePath         = $env:DATABASE_PATH
        LogPath              = $env:LOG_PATH
        SysvolPath           = $env:SYSVOL_PATH
      }

      $moduleNames = @('Microsoft.PowerShell.SecretManagement', 'az.keyVault')
      $moduleNames | ForEach-Object {
        if (-not (Get-Module -ListAvailable -Name $_)) {
          Install-PSResource -Name $_ -Repository PSGallery -Scope AllUsers -TrustRepository -PassThru -Confirm:$false
        }
      }

      $moduleNames | ForEach-Object -Parallel { Import-Module -Name $_ }

      Connect-AzAccount -UseDeviceAuthentication
      Start-Sleep -Seconds 90

      $vaultName = (Get-AzKeyVault -ResourceGroupName $ResourceGroupName -Name $KeyVaultName).VaultName
      $subscriptionId = (Get-AzContext).Subscription.Id

      $vaultParameters = @{
        AZKVaultName   = $vaultName
        SubscriptionID = $subscriptionId
      }

      Register-SecretVault -ModuleName az.keyVault -Name $vaultName -VaultParameters $vaultParameters -Confirm:$false
      $safeModeAdministratorPassword = Get-Secret -Vault $vaultName -Name $secretName

      $InstallParams['SafeModeAdministratorPassword'] = $safeModeAdministratorPassword

      Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

      Install-ADDSForest @InstallParams
    }
  }
  catch {
    Write-Error "Failed to create a new Active Directory domain. Please try again.: $_"
    exit 1
  }
  finally {
    Unregister-SecretVault -Name $vaultName -Confirm:$false
    Disconnect-AzAccount -Confirm:$false
    $ErrorActionPreference = 'Stop'
  }
}
