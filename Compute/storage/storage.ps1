<#
.SYNOPSIS
Creates a new storage pool, virtual disk, volume, and sets NTFS permissions.
.DESCRIPTION
The new-storage function creates a storage pool on the first available physical disk,
creates a virtual disk on the storage pool with maximum size, initializes the disk,
creates a partition with maximum size, formats the partition with NTFS file system,
sets NTFS permissions to allow full control for everyone, and creates a hidden directory
within the volume.
.PARAMETER storagePoolFriendlyName
The friendly name for the storage pool.
.PARAMETER virtualHardDiskFriendlyName
The friendly name for the virtual hard disk.
.PARAMETER volumeName
The name for the volume.
.PARAMETER directoryName
The name for the hidden directory to be created within the volume.
.EXAMPLE
new-storage -storagePoolFriendlyName "MyStoragePool" -virtualHardDiskFriendlyName "MyVirtualDisk" -volumeName "MyVolume" -directoryName "MyHiddenDirectory"
Creates a new storage pool named "MyStoragePool", a virtual hard disk named "MyVirtualDisk",
a volume named "MyVolume", and a hidden directory named "MyHiddenDirectory" within the volume.
.NOTES
This function requires administrative privileges.
This function requires the following PowerShell version:
- PowerShell 7.1.3 or later
This function requires the following PowerShell modules related to storage:
- Storage
This function on execution wiil return the following information:
- The file system label of the volume.
- The drive letter of the volume.
- The path to the hidden directory within the volume.
#>
function new-storage {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$storagePoolFriendlyName,
    [Parameter(Mandatory = $true)]
    [string]$virtualHardDiskFriendlyName,
    [Parameter(Mandatory = $true)]
    [string]$volumeName,
    [Parameter(Mandatory = $false)]
    [string]$directoryName,
    [Parameter(Mandatory = $false)]
    [string]$directoryPath
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

      if (!$directoryName) {
        Write-Error "No directory name specified.: $_"
        exit 1
      }
    }
  }
  finally {
    $env:DIRECTORY_PATH = Join-Path -Path $directoryPath -ChildPath $directoryName
    if (!$directoryPath) {
      $directoryPath = $driveLetter + ":"
    }
    elseif (-not (Test-Path -Path $env:DIRECTORY_PATH)) {
      New-Item -Name $directoryName -Path $env:DIRECTORY_PATH -ItemType Directory | ForEach-Object { $_.Attributes = "Hidden" }
    }
    $acl = Get-Acl -Path $env:DIRECTORY_PATH
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl -Path $env:DIRECTORY_PATH -AclObject $acl
  }
  return (Get-Volume).FileSystemLabel + " " + (Get-Partition -DiskNumber $number).DriveLetter + " " + $env:DIRECTORY_PATH
}
