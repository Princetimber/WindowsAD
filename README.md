# Introduction

As a systems engineer (Administrator), I often contemplate the challenge of automating the installation of Active Directory Domain Services (ADDS) while safeguarding my organization against the risk of exposing passwords. Over time, various administrators have devised different solutions, but many still inadvertently expose credentials.

With this consideration in mind, and given the availability of the PowerShell SecretManagement module, I aim to demonstrate how to incorporate automation using this module to install and promote a Windows Server to a domain controller securely.

## New-ADDomain.ps1
This PowerShell Script is used to create a new Active Directory Domain.

## Prerequisites
The following are prequisites and assumptions considered on this journey:
-  PowerShell 7.1.3 and later is required:
-  Please click [here](https://bit.ly/47VAj9R) for guidance on how to install PowerShell 7.
-  PowerShell module for Secret Management is also a requirement:
-  Please click [here](https://bit.ly/4bjARta) for guidance on how to install this module.
-  Whilst this is not a demonstration on how to install Windows Server Operating system. It is assumed that you have access to a server operating system in your environment.
-  Please ensure you read the commented help files before using the function. This contains detailed explanation on how to use the function.

## Parameters
-  DomainName: FQDN of the domain to be created.
-  DomainNetBiosName: The NetBios name of the doamin created.
-  DomainMode: The domain functional level of the domain to be created. This defaults to 'WinThreshold'.
-  ForestMode: The forest functional level of the domain to be created. This defaults to 'WinThreshold'.
-  DatabasePath:The path to the directory where the AD DS database is stored. This defaults to the value of '$env:SystemDrive\Windows\'. if the parameter is not specified. I strongly recommend that you use a separate disk for the database.
-  LogPath:The path to the directory where the AD DS log files are stored. This defaults to the value of '$env:SystemDrive\Windows\NTDS\'. if the parameter is not specified. I strongly recommend that you use a separate disk for the log files.
-  SysvolPath:
  The path to the directory where the AD DS system volume (SYSVOL) is stored. This defaults to the value of '$env:SystemDrive\Windows\'. if the parameter is not specified. I strongly recommend that you use a separate disk for the SYSVOL.
-  KeyVaultName: The name of the Keyvault to use.
-  ResourceGroupName: The name of the resource group where the key vault is located.
-  SecretName:The name of the secret in the Key Vault that contains the password for the Safe Mode Administrator Password.This defaults to the value of 'safeModeAdministratorPassword'.

## How to run
  -  Open PowerShell Console as an administrator.
  -  Navigate to the directory containing the script e.g. 'C:\MyScriptDirectory'
  -  Run the the command in the example below.

## Examples
New-ADDomain -DomainName 'Contoso.com' -DomainNetbiosName 'Contoso' -DatabasePath 'D:\' -LogPath 'L:\' -SysvolPath 'S:\' `
-KeyVaultName 'contoso-Keyvault' -ResourceGroupName 'Contoso-rg' -SecretName 'Contoso-SecretName'

## What the script does
-  Installs the Powershell Module
  -  Microsoft.PowerShell.SecretManagement.
  -  Az.KeyVault.
  -  Az.Accounts
-  Connects to the Azure tenant using the Az PowerShell Module e.g. Connect-AzAccount -UseDeviceAuthentication.
-  Registers a Secret Vault Using the PowerShell SecretManagement module.
-  Retrieves the SafeModeAdministratorPassword from the keyvault.
-  Installs the AD-Domain-Services Windows Feature.
-  Promotes the server to a Domain Controller by using the Install-ADDSForest Cmdlet.
-  If any error occurs during execution of the script, it writes an error message and exits with a status code of 1.
-  After the script has finished running, it unregisters the secret vault, disconnects the Azure account, and sets the `$ErrorActionPreference` to 'Stop', which means that if any future error occurs, the script will stop executing.

