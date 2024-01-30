# Introduction

As a systems engineer (Administrator), I often contemplate the challenge of automating the installation of Active Directory Domain Services (ADDS) while safeguarding my organization against the risk of exposing passwords. Over time, various administrators have devised different solutions, but many still inadvertently expose credentials.

With this consideration in mind, and given the availability of the PowerShell SecretManagement module, I aim to demonstrate how to incorporate automation using this module to install and promote a Windows Server to a domain controller securely.

The following are prequisites and assumptions considered on this journey:
(1).PowerShell 7.1.3 and later is required:
[-]Please click [here](https://bit.ly/47VAj9R) for guidance on how to install PowerShell 7.
(2) PowerShell module for Secret Management is also a requirement:
[-]Please click [here](https://bit.ly/4bjARta) for guidance on how to install this module.
[3] Whilst this is not a demonstration on how to install Windows Server Operating system. It is assumed that you have access to a server operating system in your environment.
[4] Follow the [link](//TODO) to the PowerShell function in GitHub.
[-] Please ensure you read the commented help files before using the function. This contains detailed explanation on how to use the function.
