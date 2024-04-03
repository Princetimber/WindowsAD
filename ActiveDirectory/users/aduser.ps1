$directory = 'C:\temp'
$env:DIRECTORY_PATH = Join-Path -Path $directory -ChildPath 'User.csv'
$logfile = Join-Path -Path $directory -ChildPath 'UserCreationLog.txt'
$password = Read-Host -Prompt "Enter Password" -AsSecureString

# validate Csv file exists
if (-not(Test-Path -Path $env:DIRECTORY_PATH)) {
  Write-Host "Csv file not found at $($env:DIRECTORY_PATH)" -ForegroundColor Red
  exit
}
#Retreive OU path
$ouPath = "OU=Users,OU=Managed,DC=intheclouds365,DC=com"

# Array to store log messages
$logMessages = @()

# Import the csv file and create users
$users = Import-Csv $env:DIRECTORY_PATH
foreach ($user in $users) {
  $samAccountName = $user.SamAccountName
  $domain = $user.Domain
  if (-not (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'")) {
    $param = @{
      Name                              = $user.Name
      GivenName                         = $user.GivenName
      Surname                           = $user.Surname
      DisplayName                       = $user.DisplayName
      SamAccountName                    = $samAccountName
      Company                           = $user.Company
      Department                        = $user.Department
      Organization                      = $user.Organization
      UserPrincipalName                 = [string]::Format("{0}@{1}", $samAccountName, $domain)
      AccountPassword                   = $password
      Path                              = $ouPath
      Enabled                           = $true
      AllowReversiblePasswordEncryption = $false
      ChangePasswordAtLogon             = $true
      KerberosEncryptionType            = 'AES128, AES256'
    }
    try {
      New-ADUser @param -PassThru
      $logMessages += "$samAccountName has been created successfully"
    }
    catch {
      $logMessages += "$samAccountName has not been created"
    }
  }
  else {
    $logMessages += "$samAccountName already exists"
  }
}

# Write log messages to file
$logMessages | Out-File -FilePath $logfile -Append
