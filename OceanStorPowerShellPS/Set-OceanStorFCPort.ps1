Function Set-OceanStorFCPort {
  [CmdletBinding(DefaultParameterSetName='SetPortSwitch')]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address")][PARAMETER(ParameterSetName='SetPortSwitch')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port")][PARAMETER(ParameterSetName='SetPortSwitch')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username")][PARAMETER(ParameterSetName='SetPortSwitch')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password")][PARAMETER(ParameterSetName='SetPortSwitch')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)")][PARAMETER(ParameterSetName='SetPortSwitch')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message")][PARAMETER(ParameterSetName='SetPortSwitch')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages")][PARAMETER(ParameterSetName='SetPortSwitch')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Enable - Enable or Disable port. 'Enable=true' by default!")][PARAMETER(ParameterSetName='SetPortSwitch')][bool]$Enable=$true,
	[PARAMETER(Mandatory=$True, Position=7,HelpMessage = "Port ID",ParameterSetName='SetPortSwitch')][string[]]$ID = $null
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

    $OceanStorFCPorts = Get-OceanStorFCPort -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $true

    if ($Enable) {
	  $DesiredPortState = 'Enabled'
	}`
	else {
	  $DesiredPortState = 'Disabled'
	}

    $PortJSON = New-Object PSObject -Property @{
	  PORTSWITCH = $Enable
	} | ConvertTo-Json
	  
    $BasePortURI = $RESTURI  + "fc_port"
	foreach ($CurrentPortId in $ID) {
	  $PortName = ($OceanStorFCPorts | where {$_.ID -eq $CurrentPortId}).Name

	  if (-not $PortName) {
		if (-not $Silent) { write-host "ERROR (Set-OceanStorHost): FC Port with ID $($CurrentPortId) not found!" -foreground "Red" }  
	  }`
	  else {
        if ($WhatIf) {
		  write-host "WhatIf (Set-OceanStorHost): Setting Port $($PortName)/$($CurrentPortId) state to $($DesiredPortState)" -foreground "Yellow" 
	    }
	   else {
		   
		  $URI = $BasePortURI + '/' + $($CurrentPortId)
		  
          $result = Invoke-RestMethod -Method "PUT" -Uri $URI -Body ($PortJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
            if (-not $Silent) { write-host "INFO (Set-OceanStorHost): Succesfully $($DesiredPortState) Port $($PortName)/$($CurrentPortId)" -foreground "Green" }
             $RetVal += $result.data        
            }`
            else {
              if (-not $Silent) { write-host "ERROR (New-OceanStorHost): Failed to Modify Port $($PortName)/$($CurrentPortId) [set state to $($DesiredPortState)]: $($result.error.description)" -foreground "Red" }
            }
	    }
	  }	  
    }
  
    $URI = $RESTURI  + "sessions"
    $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession  

  }
  
  Return($RetVal)   
}


