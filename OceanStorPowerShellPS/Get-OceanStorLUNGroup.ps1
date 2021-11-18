Function Get-OceanStorLUNGroup {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNGroupName')][PARAMETER(ParameterSetName='LUNID')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",                          ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNGroupName')][PARAMETER(ParameterSetName='LUNID')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",                      ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNGroupName')][PARAMETER(ParameterSetName='LUNID')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",                      ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNGroupName')][PARAMETER(ParameterSetName='LUNID')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNGroupName')][PARAMETER(ParameterSetName='LUNID')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNGroupName')][PARAMETER(ParameterSetName='LUNID')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN Group name",                ParameterSetName='LUNGroupName')][String]$Name = $null,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN Group ID",                  ParameterSetName='ID')][int]$ID = $null,
	[PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN ID",                        ParameterSetName='LUNID')][int]$LUNID = $null
  )
  $RetVal = $null
 
  # --- prepare to connect with TLS 1.2 and ignore self-signed certificate of OceanStor ---

  Fix-OceanStorConnection

  $body = @{username = "$($Username)";password = "$($Password)";scope = $Scope}
  
  $BaseRESTURI = "https://" + $OceanStor + ":" + $Port +"/deviceManager/rest/"
  $SessionURI = $BaseRESTURI  + "xxxxx/sessions"

  $logonsession = Invoke-RestMethod -Method "Post" -Uri $SessionURI -Body (ConvertTo-Json $body) -SessionVariable WebSession
  
  if ($logonsession -and ($logonsession.error.code -eq 0)) {
    $sessionid = $logonsession.data.deviceid
    $iBaseToken = $logonsession.data.iBaseToken
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $($Username),'''$($Password''')))
    $header = @{Authorization = "Basic $base64AuthInfo";iBaseToken = $iBaseToken}
    $RESTURI = $BaseRESTURI  + $sessionid +"/"

    $UserCredentials = New-Object System.Management.Automation.PsCredential("$($Username)",$(ConvertTo-SecureString -String "$($Password)" -AsPlainText -force))


    switch ( $PSCmdlet.ParameterSetName )
    {
      'ID' { $URI = $RESTURI  + "lungroup/" + $ID }
	  'LUNID' {
	    $URI = $RESTURI  + "lungroup/associate?ASSOCIATEOBJTYPE=11&ASSOCIATEOBJID=" + $LUNID
	  }
	  default { 
	    # no LUN or Group ID specified, retrieving all groups or searching group by name
	    $URI = $RESTURI  + "lungroup" 
	  }
    }
		
    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      if (-not $Name) {
	    $RetVal = $result.data		
	  }
	  else {
	    $RetVal = $result.data | where {$_.Name.ToUpper() -eq $Name.ToUpper()}
		if ((-not $RetVal) -and (-not $Silent)) {
		  write-host "ERROR (Get-OceanStorLUNGroup): LUNGroup $($Name) not found" -foreground "Red"
		}
	  }
    }
    else {
      $RetVal = $null
	  if (-not $Silent) {
	    write-host "ERROR (Get-OceanStorLUNGroup): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}


