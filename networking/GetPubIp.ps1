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
    try {
        $response = Invoke-WebRequest -Uri "https://api.ipify.org?format=json" -UseBasicParsing
        $ip = $response.Content | ConvertFrom-Json
        return $ip.ip
    }
    catch {
        Write-Warning "Unable to retrieve public IP address: $_"
        return $null
    }
}