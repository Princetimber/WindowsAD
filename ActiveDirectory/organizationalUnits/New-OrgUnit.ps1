function New-OrganizationalUnit {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)][ValidateNotNullOrEmpty()][ValidateScript({
        if (-not(Get-ADOrganizationalunit -Filter { Name -Like "$($_)" } -ErrorAction SilentlyContinue)) {
          return $true
        }
        else {
          throw "Organizational unit '$_' already exists."
        }
      })]
    [string]$Name,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)][ValidateNotNullOrEmpty()]
    [string]$Path,
    [Parameter(Mandatory = $false)]
    [string]$Description,
    [Parameter(Mandatory = $false)]
    [string]$City,
    [Parameter(Mandatory = $false)][ValidatePattern('^[A-Z]{2,3}$')]
    [string]$Country,
    [Parameter(Mandatory = $false)][ValidatePattern('^(^[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}$)|(^\d{5}(-\d{4})?$)')]
    [string]$PostalCode,
    [Parameter(Mandatory = $false)][ValidatePattern('^[A-Z][a-z]+$')]
    [string]$State,
    [Parameter(Mandatory = $false)]
    [string]$StreetAddress,
    [Parameter(Mandatory = $false)]
    [string]$ManagedBy,
    [Parameter(Mandatory = $false)][bool]$ProtectedFromAccidentalDeletion
  )
  ## Validate the Path parameter.
  if ($Path -notmatch '^(?:OU=[^,]+,?)*(?:DC=[^,]+,?)*$') {
    throw "The Path parameter must be in the format OU=?,DC=?,DC?"
    return
  }
  ## Create a hash table of parameters for the New-ADOrganizationalUnit cmdlet.
  $createParams = @{}
  $createParams['Name'] = $Name
  $createParams['Path'] = $Path
  ## The following parameters are optional.
  if ($Description) {
    $createParams['Description'] = $Description
  }
  if ($City) {
    $createParams['City'] = $City
  }
  if ($Country) {
    $createParams['Country'] = $Country
  }
  if ($PostalCode) {
    $createParams['PostalCode'] = $PostalCode
  }
  if ($State) {
    $createParams['State'] = $State
  }
  if ($StreetAddress) {
    $createParams['StreetAddress'] = $StreetAddress
  }
  if ($ManagedBy) {
    $createParams['ManagedBy'] = $ManagedBy
  }
  if ($ProtectedFromAccidentalDeletion) {
    $createParams['ProtectedFromAccidentalDeletion'] = $true
  }
  ## Create the organizational unit.
  try {

      New-ADOrganizationalUnit @createParams
      $OU = Get-ADOrganizationalUnit -Filter "Name -Like '$Name'"
      return $OU.Name + " " + $OU.DistinguishedName
  }
  catch {
    $errorMessage = $_.Exception.Message
    throw "Failed to create organizational unit '$Name' in '$Path'. Error: $errorMessage"
    return
  }
}
