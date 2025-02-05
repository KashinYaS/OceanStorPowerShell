Function Get-OceanStorFCPort {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][PARAMETER(ParameterSetName='ID')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][PARAMETER(ParameterSetName='ID')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][PARAMETER(ParameterSetName='ID')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][PARAMETER(ParameterSetName='ID')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][PARAMETER(ParameterSetName='ID')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][PARAMETER(ParameterSetName='ID')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][PARAMETER(ParameterSetName='ID')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$False,Position=7,HelpMessage = "AddCustomProps - add custom properties (CapacityGB etc.)",ParameterSetName='default')][PARAMETER(ParameterSetName='ID')][switch]$AddCustomProps,	
	[PARAMETER(Mandatory=$True, Position=8,HelpMessage = "Port ID",ParameterSetName='ID')][string[]]$ID = $null
  )
  $RetVal = @()
  
  Fix-OceanStorConnection

  $body = @{username = "$($Username)";password = "$($Password)";scope = $Scope}

  $BaseRESTURI = "https://" + $OceanStor + ":" + $Port + "/deviceManager/rest/"
  $SessionURI = $BaseRESTURI  + "xxxxx/sessions"

  $OceanStorFCPorts = $null
  
  $logonsession = Invoke-RestMethod -Method "Post" -Uri $SessionURI -Body (ConvertTo-Json $body) -SessionVariable WebSession
  
  if ($logonsession -and ($logonsession.error.code -eq 0)) {
    $sessionid = $logonsession.data.deviceid
    $iBaseToken = $logonsession.data.iBaseToken
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $($Username),'''$($Password''')))
    $header = @{Authorization = "Basic $base64AuthInfo";iBaseToken = $iBaseToken}
    $RESTURI = $BaseRESTURI  + $sessionid +"/"

    $UserCredentials = New-Object System.Management.Automation.PsCredential("$($Username)",$(ConvertTo-SecureString -String "$($Password)" -AsPlainText -force))

    $URI = $RESTURI  + "fc_port"
    $result = Invoke-RestMethod -Method Get $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      $OceanStorFCPorts = $result.data 
    }
    else {
      $OceanStorFCPorts = $null
    }
  
    $URI = $RESTURI  + "sessions"
    $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  }

  switch ( $PSCmdlet.ParameterSetName )
    {
      'ID' {
        $RetVal = $OceanStorFCPorts  | where {$ID -contains $_.ID}
	  }
	  default { 
	    $RetVal = $OceanStorFCPorts
	  }
    }

  if ($AddCustomProps) {
	  $DeviceInfo = Get-OceanStorDeviceInfo -OceanStor "$OceanStor" -Username "$Username" -Password "$Password" -Port "$Port" -Scope "$Scope" -Silent $True
	  $DeviceName = "$($DeviceInfo.Name)"
	  foreach ($Val in $RetVal) {
	    $Val | Add-Member -NotePropertyName "DeviceName" -NotePropertyValue "$($DeviceName)"
	  }
  }
  
  Return($RetVal)   
}


