Function Get-OceanStorFCPath {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "PortID - Port thru which initiator is seen",ParameterSetName='default')][string[]]$PortID='',
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "HostID - Initiator's parent host ID",ParameterSetName='default')][int[]]$HostID=''
  )
  $RetVal = @()
  
  Fix-OceanStorConnection

  $body = @{username = "$($Username)";password = "$($Password)";scope = $Scope}

  $BaseRESTURI = "https://" + $OceanStor + ":" + $Port + "/deviceManager/rest/"
  $SessionURI = $BaseRESTURI  + "xxxxx/sessions"

  if ($PortID) {
    $OceanStorPorts = Get-OceanStorFCPort -Oceanstor $OceanStor -Username $Username -Password $Password -Scope $Scope -Silent $true -ID $PortID
  }`
  else {
    $OceanStorPorts = Get-OceanStorFCPort -Oceanstor $OceanStor -Username $Username -Password $Password -Scope $Scope -Silent $true
  }
  #$OceanStorPortIDs = $OceanStorPorts.ID
  
  if ($HostID) {
    $OceanStorHosts = Get-OceanStorHost -Oceanstor $OceanStor -Username $Username -Password $Password -Scope $Scope -Silent $true -ID $HostID
  }`
  else {
    $OceanStorHosts = Get-OceanStorHost -Oceanstor $OceanStor -Username $Username -Password $Password -Scope $Scope -Silent $true
  }
  $OceanStorHostIDs = $OceanStorHosts.ID
  
  $ProcessedPorts = 0 
  foreach ($OceanStorPort in $OceanStorPorts) {
    if (-not $Silent) {
	  $PercentCompletedPorts = [math]::Floor($ProcessedPorts / $OceanStorPorts.Count * 100) 
      Write-Progress  -Activity "Processing port" -CurrentOperation $($OceanStorPort.LOCATION) -PercentComplete ($PercentCompletedPorts) -Id 1     
	}
    $PortInitiators = Get-OceanStorFCInitiator -Oceanstor $OceanStor -Username $Username -Password $Password -Scope $Scope -Silent $true -PortID ($OceanStorPort.ID) -HostID $OceanStorHostIDs
	$PortInitiators | Add-Member -MemberType NoteProperty -Name "PARENTPORTID" -Value "$($OceanStorPort.ID)"
	$PortInitiators | Add-Member -MemberType NoteProperty -Name "PARENTPORTLOCATION" -Value "$($OceanStorPort.LOCATION)"
    $RetVal += $PortInitiators
	$ProcessedPorts += 1
  }

  Return($RetVal)   
}


