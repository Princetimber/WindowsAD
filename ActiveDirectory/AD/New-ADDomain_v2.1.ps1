function New-ADModules {
  param(
    [string]$ModuleName = "AD-Domain-Services"
  )
  if (-not (Get-WindowsFeature -Name $ModuleName).Installed) {
    Install-WindowsFeature -Name $ModuleName
  }
  else {
    Write-Host "$ModuleName module is already installed"
  }
}
function Add-Password {
  param(
    [securestring]$Password = (Read-Host -Prompt "Enter the SafeModeAdministrator Password" -AsSecureString)
  )

  return $SafeModeAdministratorPassword
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
function New-ADDomainForest {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [parameter(Mandatory = $true)][bool]$InstallDNS,
    [parameter(Mandatory = $true)][string]$DomainName,
    [parameter(Mandatory = $true)][string]$DomainNetBIOSName,
    [parameter(Mandatory = $false)][string]$DomainMode = "Default",
    [parameter(Mandatory = $false)][string]$ForestMode = "Default",
    [Parameter(Mandatory = $false)][string]$DataBasePath = "C:\Windows\",
    [Parameter(Mandatory = $false)][string]$LogPath = "C:\Windows\NTDS",
    [Parameter(Mandatory = $false)][string]$SysvolPath = "C:\Windows\",
    [Parameter(Mandatory = $true)][securestring]$SafeModeAdministratorPassword,
    [switch]$Force
  )
  try {
    if ($PSCmdlet.ShouldProcess($DomainName, "Create a new Active Directory Forest!.")) {
      $Paths = @($DataBasePath, $LogPath, $SysvolPath)
      Test-Paths -Paths $Paths
      # set the environment variables
      $env:LOG_PATH = New-EnvPath -Path $LogPath -ChildPath 'logs'
      $env:DATABASE_PATH = New-EnvPath -Path $DataBasePath -ChildPath 'ntds'
      $env:SYSVOL_PATH = New-EnvPath -Path $SysvolPath -ChildPath 'SYSVOL'
      # install required modules
      New-ADModules
      # create the new forest
      $commonParams = @{
        InstallDNS                    = $true
        DomainName                    = $DomainName
        DomainNetBiosName             = $DomainNetBiosName
        DomainMode                    = $DomainMode
        ForestMode                    = $ForestMode
        DataBasePath                  = $env:DATABASE_PATH
        LogPath                       = $env:LOG_PATH
        SysvolPath                    = $env:SYSVOL_PATH
        SafeModeAdministratorPassword = $safeModeAdministratorPassword
        Force                         = $true
      }
      Install-ADDSForest @commonParams
    }
  }
  catch {
    Write-Error $_.Exception.Message
  }
}

