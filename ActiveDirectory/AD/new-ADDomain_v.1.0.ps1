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
  New-ADDomainForest -domainName "contoso.com" -domainNetBIOSName "CONTOSO" -databasePath "D:\" -logPath "D:\" -sysvolPath "E:\" -keyVaultName "contoso-keyvault" -resourceGroupName "contoso-rg" -safeModeAdministratorPassword "contoso-safeModeAdministratorPassword"
#>
$ErrorActionPreference = "Stop"
function Install-RequiredModules {
  param(
    [string[]]$moduleName = @('az.keyvault','Microsoft.PowerShell.SecretManagement')
  )
  $moduleName | ForEach-Object {
    if (-not (Get-Module -Name $_ -ListAvailable)) {
      Set-PSResourceRepository -Name PSGallery -InstallationPolicy Trusted
      Install-PSResource -Name $_ -Repository PSGallery -Scope AllUsers -Confirm:$false
    }
    Import-Module -Name $_ -Force
  }
}
function Install-RequiredADModules {
  [string]$ModuleName = 'AD-Domain-Services'
  if (-not (Get-WindowsFeature -Name $ModuleName)) {
    Install-WindowsFeature -Name $ModuleName -IncludeManagementTools
  }
}
function Add-keys{
  param($hash, $keys)
  $keys.GetEnumerator() | ForEach-Object {
    $hash.Add($_.Key, $_.Value)
  }
}
function New-EnvPath {
  param(
    [string]$Path,
    [string]$ChildPath
  )
  return Join-Path -Path $Path -ChildPath $ChildPath
}
function Test-Paths {
  param(
    [string[]]$Paths 
  )
  $paths | ForEach-Object {
    if (-not (Test-Path -Path $_)) {
      throw "Path $_ does not exist"
    }
  }
}
function Connect-ToAzure {
  Connect-AzAccount -UseDeviceAuthentication
  $timeout = New-TimeSpan -Seconds 90
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed -lt $timeout) {
    $context = (Get-AzContext -ErrorAction SilentlyContinue).Account
    if ($context) {
      break
    }
    Start-Sleep -Seconds 5
  }
}
function Get-Vault {
  param(
    [string]$keyVaultName,
    [string]$ResourceGroupName
  )
  Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $keyVaultName
}

function Add-RegisteredSecretVault {
  param(
    [string]$Name = (Get-Vault).VaultName,
    [string]$ModuleName,
    [hashtable]$VaultParameters
  )
  Register-SecretVault -Name $Name -ModuleName $ModuleName -VaultParameters $VaultParameters -Confirm:$false
}
function New-ADDomainForest {
  [CmdletBinding(SupportsShouldProcess  = $true)]
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
    [string]$secretName,
    [Parameter(Mandatory = $false)]
    [switch]$Force
  )
  try {
    if($PSCmdlet.ShouldProcess($DomainName,"Create a new Active Directory Forest")){
      $Paths = @($DatabasePath, $LogPath, $SysvolPath)
      Test-Paths -Paths $Paths
      # set the environment variables
      $env:LOG_PATH = New-EnvPath -Path $LogPath -ChildPath 'logs'
      $env:DATABASE_PATH = New-EnvPath -Path $DatabasePath -ChildPath 'ntds'
      $env:SYSVOL_PATH = New-EnvPath -Path $SysvolPath -ChildPath 'SYSVOL'
      # install required modules
      Install-RequiredModules
      Install-RequiredADModules
      # connect to azure
      Connect-ToAzure
      # get the vault
      $vaultName = (Get-Vault -keyVaultName $KeyVaultName -ResourceGroupName $ResourceGroupName).VaultName
      # register the secret vault
      $vaultParameters = @{
        AZKVaultName = $KeyVaultName
        SubscriptionId = (Get-AzContext).Subscription.Id
      }
      $ModuleName = 'az.keyvault'
      $param = @{
        Name = $vaultName
        VaultParameters = $vaultParameters
        ModuleName = $ModuleName
      }
      Add-RegisteredSecretVault @param
      # define common parameters
      $commonParams = @{
        InstallDNS = $true
        DomainName = $DomainName
        DomainNetBiosName = $DomainNetBiosName
        DomainMode = $DomainMode
        ForestMode = $ForestMode
        DatabasePath = $env:DATABASE_PATH
        LogPath = $env:LOG_PATH
        SysvolPath = $env:SYSVOL_PATH
        Force = $true
      }
      # retrieve the safe mode administrator password
      $safeModeAdministratorPassword = Get-Secret -Name $secretName -Vault $vaultName
      param = $commonParams.Clone()
      $keys = @{
        SafeModeAdministratorPassword = $safeModeAdministratorPassword
      }
      Add-keys -hash $param -keys $keys
      # create the new AD Forest
      Install-ADDSForest @param
    }
    else{
      Write-Output "The Operation cancelled"
    }
  }
  catch {
    Write-Error -Message "Failed to create the new AD Forest. Please see the error message below.:$_"
  }
  finally {
    # unregister the secret vault
    Unregister-SecretVault -Name $vaultName -Confirm:$false
    Disconnect-AzAccount -Confirm:$false
  }
}
