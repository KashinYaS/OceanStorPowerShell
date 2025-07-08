# OceanStorPowerShell
PowerShell comandlets for Huawei OceanStor / Dorado storage to deal with em simplier with RESTful API

Import all functions:
Import-Module c:\Users\User\Documents\GitHub\OceanStorPowerShell\OceanStorPowerShell

## WARNING !!!
"Silent" argument is not a switch, but "WhatIf" - is.
Trying to pass $true or $false to WhatIf ruins argument parsing in powershell leading to unexpected behaviour sometimes.