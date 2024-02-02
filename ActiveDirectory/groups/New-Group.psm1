[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidateScript({
      if (-not(Get-ADGroup -Filter { Name -Like "$($_)" } -ErrorAction SilentlyContinue)) {
        return $true
      }
      else {
        throw "Group '$_' already exists."
      }
    })]
  [string]$Name,
  [Parameter(Mandatory = $true)]
  [string]$Path,
  [Parameter(Mandatory = $true)][ValidateSet('Security', 'Distribution')]
  [string]$GroupCategory,
  [Parameter(Mandatory = $true)][ValidateSet('Global', 'DomainLocal', 'Universal')]
  [string]$GroupScope,
  [Parameter(Mandatory = $false)]
  [string]$DisplayName,
  [Parameter(Mandatory = $false)]
  [string]$SamAccountName,
  [Parameter(Mandatory = $false)]
  [string]$Description
)
## Validate the Path parameter.
if ($Path -notmatch '^(?:OU=[^,]+,?)*(?:DC=[^,]+,?)*$') {
  throw "The Path parameter must be in the format OU=?,DC=?,DC?"
  return
}
## Create a hash table of parameters for the New-ADGroup cmdlet.
$createParams = @{}
$createParams['Name'] = $Name
$createParams['Path'] = $Path
$createParams['GroupCategory'] = $GroupCategory
$createParams['GroupScope'] = $GroupScope
## The following parameters are optional.
if ($Description) {
  $createParams['Description'] = $Description
}
if ($DisplayName) {
  $createParams['DisplayName'] = $DisplayName
}
if ($SamAccountName) {
  $createParams['SamAccountName'] = $SamAccountName
}
## Create the group.
try {
  if ($PSCmdlet.ShouldProcess($Name, 'Create a new group')) {
    New-ADGroup @createParams
  }
  elseif ($PSCmdlet.ShouldContinue("Do you want to continue?")) {
    New-ADGroup @createParams
  }
}
catch {
  $errorMessage = $_.Exception.Message
  throw "Failed to create group '$Name' in '$Path'. Error: $errorMessage"
}

function Update-ADPrincipalGroupMemebership {
  [CmdletBinding(DefaultParameterSetName = 'AddPrincipalGroupMembership, RemovePrincipalGroupMembership', SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)][ValidateScript({
        if (Get-ADGroup -Identity $_ -ErrorAction SilentlyContinue) {
          return $true
        }
        else {
          throw "Group '$_' does not exist."
        }
      })][string]$GroupName,
    [Parameter(Mandatory = $true)][ValidateSet('Domain Admins', 'Enterprise Admins', 'Group Policy Creator Owners', 'Schema Admins')]
    [string]$SecurityGroup,
    [Parameter(Mandatory = $true, ParameterSetName = 'AddPrincipalGroupMembership')]
    [switch]$AddPrincipalGroupMembership,
    [Parameter(Mandatory = $true, ParameterSetName = 'RemovePrincipalGroupMembership')]
    [switch]$RemovePrincipalGroupMembership
  )
  ## Get the the distinguished names of the groups to be added or removed.
  $memberOf = (Get-ADGroup -Identity $SecurityGroup).DistinguishedName

  ## Get the distinguished name of the group to be modified.
  $identity = (Get-ADGroup -Identity $GroupName).DistinguishedName

  ## Add the group to the security group.
  switch ($PSCmdlet.ParameterSetName) {
    'AddPrincipalGroupMembership' {
      if ($AddPrincipalGroupMembership.IsPresent -and $PSCmdlet.ShouldProcess($GroupName, "Add group '$GroupName' to '$SecurityGroup'")) {
        try {
          Add-ADGroupMember -Identity $memberOf -Members $identity
        }
        catch {
          $errorMessage = $_.Exception.Message
          throw "Failed to add group '$GroupName' to '$SecurityGroup'. Error: $errorMessage"
        }
      }
      elseif ($AddPrincipalGroupMembership.IsPresent -and $PSCmdlet.ShouldContinue("Do you want to continue?")) {
        try {
          Add-ADGroupMember -Identity $memberOf -Members $identity
        }
        catch {
          $errorMessage = $_.Exception.Message
          throw "Failed to add group '$GroupName' to '$SecurityGroup'. Error: $errorMessage"
        }
      }
    }
    'RemovePrincipalGroupMembership' {
      if ($RemovePrincipalGroupMembership.IsPresent -and $PSCmdlet.ShouldProcess($GroupName, "Remove group '$GroupName' from '$SecurityGroup'")) {
        try {
          Remove-ADGroupMember -Identity $memberOf -Members $identity
        }
        catch {
          $errorMessage = $_.Exception.Message
          throw "Failed to remove group '$GroupName' from '$SecurityGroup'. Error: $errorMessage"
        }
      }
      elseif ($RemovePrincipalGroupMembership.IsPresent -and $PSCmdlet.ShouldContinue("Do you want to continue?")) {
        try {
          Remove-ADGroupMember -Identity $memberOf -Members $identity
        }
        catch {
          $errorMessage = $_.Exception.Message
          throw "Failed to remove group '$GroupName' from '$SecurityGroup'. Error: $errorMessage"
        }
      }
    }
  }
}
