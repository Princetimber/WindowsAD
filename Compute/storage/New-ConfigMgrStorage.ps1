function New-ConfigMgrStorage {
  [CmdletBinding(DefaultParameterSetName = 'CreateSMSFile, CreateDBDirectory')]
  param(
    [Parameter(Mandatory = $true)]
    [string]$storagePoolFriendlyName,
    [Parameter(Mandatory = $true)]
    [string]$virtualHardDiskFriendlyName,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)][ValidateSet('ConfigMgr Install', 'SCCM_SQL_MDF', 'SCCM_SQL_LDF', 'SQL_TempDB', 'SQL_WSUS_Database', 'SCCM_Application_Sources', 'SCCM_ContentLibrary', 'SQL_test')]
    [string]$volumeName,
    [Parameter(Mandatory = $false)]
    [string]$fileName = "no_sms_on_drive.sms",
    [Parameter(Mandatory = $false)]
    [string]$directoryName = "Database",
    [Parameter(Mandatory = $true, ParameterSetName = 'CreateSMSFile')]
    [switch]$createSMSFile,
    [Parameter(Mandatory = $true, ParameterSetName = 'CreateDBDirectory')]
    [switch]$createDBDirectory
  )
  $disks = Get-PhysicalDisk -CanPool $true
  if ($disks.Count -eq 0) {
    Write-Error "No physical disks available for storage pool.: $_"
    return
  }
  try {
    if ($disks.Count -ge 1) {
      $disk = $disks | Select-Object -First 1
      $storageSubsystemFriendlyName = (Get-StorageSubSystem).FriendlyName
      New-StoragePool -FriendlyName $storagePoolFriendlyName -StorageSubSystemFriendlyName $storageSubsystemFriendlyName -PhysicalDisks $disk

      New-VirtualDisk -StoragePoolFriendlyName $storagePoolFriendlyName -FriendlyName $virtualHardDiskFriendlyName -UseMaximumSize -ProvisioningType Fixed -ResiliencySettingName Simple -MediaType SSD

      $number = (Get-VirtualDisk -FriendlyName $virtualHardDiskFriendlyName | Get-Disk).Number

      Initialize-Disk -Number $number -PartitionStyle GPT

      New-Partition -DiskNumber $number -UseMaximumSize -AssignDriveLetter

      $driveLetter = (Get-Partition -DiskNumber $number | Where-Object { $_.Type -EQ "Basic" }).DriveLetter
      Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel $volumeName -Confirm:$false
    }
    Write-Information "Volume $volumeName created successfully: $_"
  }
  finally {
    $env:DIRECTORY_PATH = (Get-Volume | Where-Object { $_.FileSystemLabel -eq $volumeName }).DriveLetter + ":"
    switch ($PSCmdlet.ParameterSetName) {
      'CreateSMSFile' {
        try {
          if ($createSMSFile.IsPresent -and (-not(Test-Path -Path (Join-Path -Path $env:DIRECTORY_PATH -ChildPath $fileName)))) {
            New-Item -Name $fileName -ItemType file -Path $env:DIRECTORY_PATH
          }
        }
        catch {
          $errorMessage = $_.Exception.Message
          throw "Failed to create file '$fileName' in '$env:DIRECTORY_PATH'. Error: $errorMessage"
        }
      }
      'CreateDBDirectory' {
        try {
          if ($createDBDirectory.IsPresent -and (-not(Test-Path -Path (Join-Path -Path $env:DIRECTORY_PATH -ChildPath $directoryName)))) {
            New-Item -Name $directoryName -Path $env:DIRECTORY_PATH -ItemType Directory
            New-Item -Name $fileName -Path $env:DIRECTORY_PATH -ItemType File
          }
        }
        catch {
          $errorMessage = $_.Exception.Message
          throw "Failed to create directory '$directoryName' in '$env:DIRECTORY_PATH'. Error: $errorMessage"
        }
      }
    }
  }
  return  (Get-Volume).FileSystemLabel + " " + (Get-Partition -DiskNumber $number).DriveLetter + " " + ($env:DIRECTORY_PATH + $fileName)
}
