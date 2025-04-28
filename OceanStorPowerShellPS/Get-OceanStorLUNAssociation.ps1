Function Get-OceanStorLUNAssociation {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='HostID')][PARAMETER(ParameterSetName='LunGroupId')][PARAMETER(ParameterSetName='LunId')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='HostID')][PARAMETER(ParameterSetName='LunGroupId')][PARAMETER(ParameterSetName='LunId')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='HostID')][PARAMETER(ParameterSetName='LunGroupId')][PARAMETER(ParameterSetName='LunId')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='HostID')][PARAMETER(ParameterSetName='LunGroupId')][PARAMETER(ParameterSetName='LunId')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='HostID')][PARAMETER(ParameterSetName='LunGroupId')][PARAMETER(ParameterSetName='LunId')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='HostID')][PARAMETER(ParameterSetName='LunGroupId')][PARAMETER(ParameterSetName='LunId')][bool]$Silent=$true,
	[PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Host ID",ParameterSetName='HostID')][int]$HostID = $null,
	[PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN Group ID",ParameterSetName='LunGroupId')][int]$LunGroupId = $null,
	[PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN ID",ParameterSetName='LunId')][int]$LunId = $null
  )
  $RetVal = $null
 
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
      'HostID' {
	    $URI = $RESTURI  + "lun/associate?ASSOCIATEOBJTYPE=21&ASSOCIATEOBJID=$($HostID)"
	  }
      'LunGroupId' {
	    $URI = $RESTURI  + "lun/associate?ASSOCIATEOBJTYPE=256&ASSOCIATEOBJID=$($LunGroupId)"
	  }
      'LunId' {
	    $URI = $RESTURI  + "lun/associate?ASSOCIATEOBJTYPE=11&ASSOCIATEOBJID=$($LunId)"
	  }
	  default { 
	    $URI = $RESTURI  + "lun/associate" 
	  }
    }

    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      switch ( $PSCmdlet.ParameterSetName )
      {
        'HostID' {
	      $RetVal = $result.data		
		}		  
        'LunGroupId' {
	      $RetVal = $result.data		
		}
	    default { 
	      $RetVal = $result.data 
	    }
      }	
    }
    else {
      $RetVal = $null
	  if (-not $Silent) {
	    write-host "ERROR (Get-OceanStorLUNAssociation): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
   
  Return($RetVal)
}

