Function Get-OceanStorInventory {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][bool]$Silent=$true
  )
  $RetVal = @()

  $OSInfo = Get-OceanStorDeviceInfo -Oceanstor $OceanStor -Username $Username -Password $Password -Scope $Scope -Silent $true
  
  $OSEnclosure = Get-OceanStorEnclosure -Oceanstor $OceanStor -Username $Username -Password $Password -Scope $Scope -Silent $true
  $OSEnclosure | Add-Member -NotePropertyName 'OceanStorName' -NotePropertyValue "$($OSInfo.Name)"
  $RetVal += ($OSEnclosure | select OceanStorName,Name,@{N="Location";E={$_.Name}},@{N="ESN";E={$_.SERIALNUM}},@{N="Model";E={$_.ModelNameEx}})

  $OSIOModule = Get-OceanStorInterfaceModule -Oceanstor $OceanStor -Username $Username -Password $Password -Scope $Scope -Silent $true
  $OSIOModule | Add-Member -NotePropertyName 'OceanStorName' -NotePropertyValue "$($OSInfo.Name)"
  $RetVal += ($OSIOModule | select OceanStorName,Name,Location,@{N='ESN';E={($_.ELABEL.Split([Environment]::NewLine) | where {$_ -like 'Barcode*'}).Split('=')[1]}},@{N="Model";E={$_.ModelNameEx}})

  $OSDisk = Get-OceanStorDisk -Oceanstor $OceanStor -Username $Username -Password $Password -Scope $Scope -Silent $true
  $OSDisk | Add-Member -NotePropertyName 'OceanStorName' -NotePropertyValue "$($OSInfo.Name)"
  $RetVal += ($OSdisk | select OceanStorName,@{N="Name";E={"Disk "+ $($_.ID)}},Location,@{N="ESN";E={$_.Barcode}},@{N='Model';E={($_.ELABEL.Split([Environment]::NewLine) | where {$_ -like 'Description*'}).Split('=')[1]}})
  
  Return($RetVal)
}

