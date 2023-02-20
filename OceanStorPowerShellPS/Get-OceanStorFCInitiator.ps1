Function Get-OceanStorFCInitiator {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][bool]$Silent=$true,
	[PARAMETER(Mandatory=$False,Position=6,HelpMessage = "PortID - Port thru which initiator is seen",ParameterSetName='default')][string]$PortID='',
	[PARAMETER(Mandatory=$False,Position=6,HelpMessage = "HostID - Initiator's parent host ID",ParameterSetName='default')][string[]]$HostID=''
  )
  $RetVal = @()
  
  Fix-OceanStorConnection

  $body = @{username = "$($Username)";password = "$($Password)";scope = $Scope}

  $BaseRESTURI = "https://" + $OceanStor + ":" + $Port + "/deviceManager/rest/"
  $SessionURI = $BaseRESTURI  + "xxxxx/sessions"

  $OceanStorFCInitiators = $null
  
  $logonsession = Invoke-RestMethod -Method "Post" -Uri $SessionURI -Body (ConvertTo-Json $body) -SessionVariable WebSession
  
  if ($logonsession -and ($logonsession.error.code -eq 0)) {
    $sessionid = $logonsession.data.deviceid
    $iBaseToken = $logonsession.data.iBaseToken
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $($Username),'''$($Password''')))
    $header = @{Authorization = "Basic $base64AuthInfo";iBaseToken = $iBaseToken}
    $RESTURI = $BaseRESTURI  + $sessionid +"/"

    $UserCredentials = New-Object System.Management.Automation.PsCredential("$($Username)",$(ConvertTo-SecureString -String "$($Password)" -AsPlainText -force))

    $Body = @{}
	
	if ($HostID -and ($HostID.Count -eq 1)) {
	  $HostBodyAdd = @{'PARENTID' = "$HostID"}
	  $Body += $HostBodyAdd
	}

	if ($PortID) {
	  $PortBodyAdd = @{'ASSOCIATEOBJID' = "$PortID"; 'ASSOCIATEOBJTYPE' = '212'}
	  $Body += $PortBodyAdd
	}
		
    $URI = $RESTURI  + "fc_initiator"
    $result = Invoke-RestMethod -Method Get $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -Body $Body -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      $OceanStorFCInitiators = $result.data | where {$_.TYPE -eq "223"}
	  
	  if ($HostID -and ($HostID.Count -gt 1)) {
	    $OceanStorFCInitiators = $OceanStorFCInitiators | where {$HostId -contains $_.PARENTID}
	  }
	  
    }
    else {
      $OceanStorFCInitiators = $null
    }
  
    $URI = $RESTURI  + "sessions"
    $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession 
  }
 
  $RetVal = $OceanStorFCInitiators  
  Return($RetVal)   
}


