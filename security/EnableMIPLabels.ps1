#Install-Module Microsoft.Graph -Scope CurrentUser
#Install-Module Microsoft.Graph.Beta -Scope CurrentUser

#Connect-MgGraph -Scopes "Directory.ReadWrite.All"

Get-MgBetaDirectorySettingTemplate

$TemplateId = (Get-MgBetaDirectorySettingTemplate | Where-Object { $_.DisplayName -eq "Group.Unified" }).Id
$Template = Get-MgBetaDirectorySettingTemplate | Where-Object -Property Id -Value $TemplateId -EQ
$Template

Get-MgBetaDirectorySetting

$grpUnifiedSetting = Get-MgBetaDirectorySetting | Where-Object { $_.Values.Name -eq "EnableMIPLabels" }
$grpUnifiedSetting.Values

$params = @{
  templateId = $TemplateId
  values     = @(
    @{
      name  = "EnableMIPLabels"
      value = "True"
    }
  )
}
New-MgBetaDirectorySetting -BodyParameter $params

$params = @{
  Values = @(
    @{
      Name  = "EnableMIPLabels"
      Value = "True"
    }
  )
}
Update-MgBetaDirectorySetting -DirectorySettingId $grpUnifiedSetting.Id -BodyParameter $params

$Setting = Get-MgBetaDirectorySetting -DirectorySettingId $grpUnifiedSetting.Id
$Setting.Values