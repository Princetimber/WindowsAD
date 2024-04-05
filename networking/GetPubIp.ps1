<#
.SYNOPSIS
Get your public IP address

.DESCRIPTION
Get your public IP address using the ipify API

.EXAMPLE
Get-MyIP

.NOTES
Author: Olamide Olaleye
Date: 2024-04-05
#>
function Get-MyIP {
    $ip = Invoke-WebRequest -Uri "https://api.ipify.org?format=json" | ConvertFrom-Json
    $ip.ip
}
