<#
.SYNOPSIS
Creates a new storage pool, virtual disk, volume, and sets NTFS permissions.
.DESCRIPTION
The New-Storage function creates a storage pool on the first available physical disk,
creates a virtual disk on the storage pool with maximum size, initializes the disk,
creates a partition with maximum size, formats the partition with NTFS file system,
sets NTFS permissions to allow full control for everyone, and creates a hidden directory
within the volume.
.PARAMETER StoragePoolFriendlyName
The friendly name for the storage pool.
.PARAMETER VirtualHardDiskFriendlyName
The friendly name for the virtual hard disk.
.PARAMETER FileSystemLabel
The name for the volume.
.PARAMETER DirectoryName
The name for the hidden directory to be created within the volume.
.PARAMETER CreateDirectory
Creates a hidden SYSVOL directory within the volume.
.PARAMETER CreateNTDSDirectory
Creates a hidden NTDS and LOGS directories within the volume.
.EXAMPLE
New-Storage -StoragePoolFriendlyName "MyStoragePool" -VirtualHardDiskFriendlyName "MyVirtualDisk" -FileSystemLabel "MyVolume" -DirectoryName "MyHiddenDirectory" -CreateDirectory
Creates a new storage pool named "MyStoragePool", a virtual hard disk named "MyVirtualDisk",
a volume named "MyVolume", and a hidden directory named "MyHiddenDirectory" within the volume.
.EXAMPLE
New-Storage -StoragePoolFriendlyName "MyStoragePool" -VirtualHardDiskFriendlyName "MyVirtualDisk" -FileSystemLabel "MyVolume" -DirectoryName "MyHiddenDirectory" -CreateNTDSDirectory
.NOTES
This function requires administrative privileges.
This function requires the following PowerShell version:
- PowerShell 7.1.3 or later
This function requires the following PowerShell modules related to storage:
- Storage
This function on execution will return the following information:
- The file system label of the volume.
- The drive letter of the volume.
- The path to the hidden directory within the volume.
#>
function New-Storage {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$StoragePoolFriendlyName,
    [Parameter(Mandatory = $true)]
    [string]$VirtualHardDiskFriendlyName,
    [Parameter(Mandatory = $true)][ValidateSet('SYSVOL', 'NTDS')]
    [string]$FileSystemLabel,
    [Parameter(Mandatory = $true)][ValidateSet('SYSVOL', 'NTDS')]
    [string]$DirectoryName,
    [Parameter(Mandatory = $true, ParameterSetName = 'CreateDirectory')]
    [switch]$CreateDirectory,
    [Parameter(Mandatory = $true, ParameterSetName = 'CreateNTDSDirectory')]
    [switch]$CreateNTDSDirectory
  )

  $physicalDisks = Get-PhysicalDisk -CanPool $true
  if ($physicalDisks.Count -eq 0) {
    Write-Host "No physical disks available for storage pool creation."
    return
  }

  try {
    $disk = $physicalDisks | Select-Object -First 1
    $storageSubsystemFriendlyName = (Get-StorageSubSystem).FriendlyName
    New-StoragePool -FriendlyName $StoragePoolFriendlyName -StorageSubSystemFriendlyName $storageSubsystemFriendlyName -PhysicalDisks $disk
    New-VirtualDisk -FriendlyName $VirtualHardDiskFriendlyName -StoragePoolFriendlyName $StoragePoolFriendlyName -UseMaximumSize -ProvisioningType Fixed -ResiliencySettingName Simple -MediaType SSD
    $number = (Get-VirtualDisk -FriendlyName $VirtualHardDiskFriendlyName | Get-Disk).Number
    Initialize-Disk -Number $number -PartitionStyle GPT
    New-Partition -DiskNumber $number -UseMaximumSize -AssignDriveLetter
    $driveLetter = (Get-Partition -DiskNumber $number | Where-Object { $_.Type -eq 'Basic' }).DriveLetter
    Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel $FileSystemLabel -Confirm:$false
  }
  catch {
    Write-Error "An error occurred while creating the storage pool: $_"
    return
  }

  $env:DIRECTORY_PATH = (Get-Volume | Where-Object { $_.FileSystemLabel -eq $FileSystemLabel }).DriveLetter + ":"
  $directoryPath = Join-Path -Path $env:DIRECTORY_PATH -ChildPath $DirectoryName

  switch ($PSCmdlet.ParameterSetName) {
    'CreateDirectory' {
      try {
        if ($CreateDirectory.IsPresent -and (-not (Test-Path -Path $directoryPath))) {
          New-Item -Path $directoryPath -ItemType Directory | ForEach-Object { $_.Attributes = 'Hidden' }
          Set-DirectoryAcl -Path $directoryPath
        }
      }
      catch {
        Write-Error "An error occurred while creating the directory: $_"
      }
    }
    'CreateNTDSDirectory' {
      try {
        $logsPath = Join-Path -Path $directoryPath -ChildPath "LOGS"
        if ($CreateNTDSDirectory.IsPresent -and (-not (Test-Path -Path $directoryPath)) -and (-not (Test-Path -Path $logsPath))) {
          New-Item -Path $directoryPath -ItemType Directory | ForEach-Object { $_.Attributes = 'Hidden' }
          New-Item -Path $logsPath -ItemType Directory
          Set-DirectoryAcl -Path $directoryPath
          Set-DirectoryAcl -Path $logsPath
        }
      }
      catch {
        Write-Error "An error occurred while creating the log directory: $_"
      }
    }
  }

  return (Get-Volume).FileSystemLabel + (Get-Volume).DriveLetter
}

function Set-DirectoryAcl {
  param (
    [string]$Path
  )
  $acl = Get-Acl -Path $Path
  $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
  $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
  $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Authenticated Users", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")))
  Set-Acl -Path $Path -AclObject $acl
}
