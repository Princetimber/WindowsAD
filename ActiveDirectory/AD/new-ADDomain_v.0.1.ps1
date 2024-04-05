<#
.SYNOPSIS
  This function installs a new Active Directory domain in Azure or on-premises.
.DESCRIPTION
  This function installs a new Active Directory domain in Azure or on-premises.
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
.NOTES
  File Name      : New-ADDomain.ps1
  Author         : Olamide Olaleye
  Prerequisite   : PowerShell 7.1.3 or later
  Modules        : Microsoft.PowerShell.SecretManagement, az.keyVault
  Windows Features: AD-Domain-Services
  Key Vault      : The Key Vault must be created and the secret must be created in the Key Vault that contains the password for the Safe Mode Administrator Password.
  Registered Vault: The Key Vault is registered as a secret vault using the Register-SecretVault cmdlet.
  Secret Retrieval: The Safe Mode Administrator Password is retrieved from the Key Vault using the Get-Secret cmdlet.
  Online Version:
.LINK
  Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
  New-ADDomain -domainName "contoso.com" -domainNetBIOSName "CONTOSO" -databasePath "D:\" -logPath "D:\" -sysvolPath "E:\" -keyVaultName "contoso-keyvault" -resourceGroupName "contoso-rg" -safeModeAdministratorPassword "contoso-safeModeAdministratorPassword"
#>

function install-RequiredModules {
  param(
    [Parameter(Mandatory = $false)]
    [string[]]$moduleName = @('az.keyvault','Microsoft.PowerShell.SecretManagement')
  )
  $moduleName | ForEach-Object {
    if (-not (Get-Module -Name $_ -ListAvailable)) {
      Set-PSResourceRepository -Name PSGallery -InstallationPolicy Trusted
      Install-PSResource -Name $_ -Repository PSGallery -Scope CurrentUser -Confirm:$false
    }
    Import-Module -Name $_ -Force
  }
}
function Add-keys{
  param($hash, $keys)
  $keys.GetEnumerator() | ForEach-Object {
    $hash.Add($_.Key, $_.Value)
  }
}

function New-ADDomain {
  [CmdletBinding(SupportsShouldProcess=$true)]
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
    [string]$secretName = "safeModeAdministratorPassword",
    [Parameter(Mandatory = $false)]
    [switch]$Force
  )
  $ErrorActionPreference = "Stop"
  try {
    if($PSCmdlet.ShouldProcess($DomainName,'Create a new Active Directory domain')){
      # validate the path
      $path = @($DatabasePath, $LogPath, $SysvolPath)
      $path | ForEach-Object {
        if (-not (Test-Path -Path $_)) {
          throw "The path does not exist. Please try again.: $_"
        }
      }

      # set the environment variables
      $env:LOG_PATH = Join-Path -Path $LogPath -ChildPath 'logs'
      $env:DATABASE_PATH = Join-Path -Path $DatabasePath -ChildPath 'ntds'
      $env:SYSVOL_PATH = Join-Path -Path $SysvolPath -ChildPath 'SYSVOL'

      # install the ADDSDeployment module
      if(-not(Get-WindowsFeature -Name AD-Domain-Services)){
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
      }

      #  connect to azure
      Connect-AzAccount -UseDeviceAuthentication
      Start-Sleep -Seconds 90

      #  define the common parameters
      $commonParams = @{
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

      # get the secret
      $vaultName = (Get-AzKeyVault -ResourceGroupName $ResourceGroupName -Name $KeyVaultName).VaultName
      $subscriptionId = (Get-AzContext).Subscription.Id

      $vaultParam = @{
        AZKVaultName = $vaultName
        SubscriptionId = $subscriptionId
      }
      Register-SecretVault -ModuleName az.keyVault -Name $vaultName -VaultParameters $vaultParam -Confirm:$false

      # get the secret
      $safeModeAdministratorPassword = Get-Secret -Name $secretName -Vault $vaultName
      $param = $commonParams.Clone()
      $keys = @{'SafeModeAdministratorPassword' = $safeModeAdministratorPassword}
      Add-keys -hash $param -keys $keys

      # Promote the server to a domain controller
      Install-ADDSForest @param
    }
    elseif($PSCmdlet.ShouldContinue("Do you want to continue with promoting the server to a domain controller?")){
      # validate the path
      $path = @($DatabasePath, $LogPath, $SysvolPath)
      $path | ForEach-Object {
        if (-not (Test-Path -Path $_)) {
          throw "The path does not exist. Please try again.: $_"
        }
      } 

      # set the environment variables
      $env:LOG_PATH = Join-Path -Path $LogPath -ChildPath 'logs'
      $env:DATABASE_PATH = Join-Path -Path $DatabasePath -ChildPath 'ntds'
      $env:SYSVOL_PATH = Join-Path -Path $SysvolPath -ChildPath 'SYSVOL'
      
      # install the ADDSDeployment module
      if(-not(Get-WindowsFeature -Name AD-Domain-Services)){
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
      }

      #  connect to azure
      Connect-AzAccount -UseDeviceAuthentication
      Start-Sleep -Seconds 90

      #  define the common parameters
      $commonParams = @{
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

      # get the secret
      $vaultName = (Get-AzKeyVault -ResourceGroupName $ResourceGroupName -Name $KeyVaultName).VaultName
      $subscriptionId = (Get-AzContext).Subscription.Id

      $vaultParam = @{
        AZKVaultName = $vaultName
        SubscriptionId = $subscriptionId
      }
      Register-SecretVault -ModuleName az.keyVault -Name $vaultName -VaultParameters $vaultParam -Confirm:$false

      # get the secret
      $safeModeAdministratorPassword = Get-Secret -Name $secretName -Vault $vaultName
      $param = $commonParams.Clone()
      param['SafeModeAdministratorPassword'] = $safeModeAdministratorPassword
      $keys = @{'SafeModeAdministratorPassword' = $safeModeAdministratorPassword}
      Add-keys -hash $param -keys $keys

      # Promote the server to a domain controller
      Install-ADDSForest @param
    }
    else{
      Write-Host "The operation was cancelled"
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
