Function Get-OceanStorPower {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][int]$Scope=0,
	[PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][bool]$Silent=$true
  )
  $RetVal = $null
  
  Fix-OceanStorConnection

  $body = @{username = "$($Username)";password = "$($Password)";scope = $Scope}

  $BaseRESTURI = "https://" + $OceanStor + ":" + $Port + "/deviceManager/rest/"
  $SessionURI = $BaseRESTURI  + "xxxxx/sessions"

  $logonsession = Invoke-RestMethod -Method "Post" -Uri $SessionURI -Body (ConvertTo-Json $body) -SessionVariable WebSession

  if ($logonsession -and ($logonsession.error.code -eq 0)) {
      $sessionid = $logonsession.data.deviceid
      $iBaseToken = $logonsession.data.iBaseToken
      $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $($Username),'''$($Password''')))
      $header = @{Authorization = "Basic $base64AuthInfo";iBaseToken = $iBaseToken}
      $RESTURI = $BaseRESTURI  + $sessionid +"/"

      $UserCredentials = New-Object System.Management.Automation.PsCredential("$($Username)",$(ConvertTo-SecureString -String "$($Password)" -AsPlainText -force))

	  $URI = $RESTURI  + "get_realtime_power_consumption"
	
      try {	
        $result = Invoke-RestMethod -Method "Get" -Uri $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
        if ($result -and ($result.error.code -eq 0)) {
          $RetVal = $result.data.powerConsumptionValue        
        }
        else {			
          if (-not $Silent) { write-host "ERROR (Get-OceanStorPower): Current power Consumption is not available" -foreground "Red" }
		  $RetVal = $null
        }
	  }
	  catch {
		$RetVal = $null
        if (-not $Silent) { write-host "ERROR (Get-OceanStorPower): Current power Consumption is not available (no HTTP reply or page unavailable)" -foreground "Red" }		
	  }
	
      $URI = $RESTURI  + "sessions"
      $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession  
  }
  
  Return($RetVal)
}

