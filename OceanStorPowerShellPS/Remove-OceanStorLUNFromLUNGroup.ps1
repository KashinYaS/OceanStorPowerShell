Function Remove-OceanStorLUNFromLUNGroup {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN ID",ParameterSetName='Default')][int[]]$LUNID = $null,
    [PARAMETER(Mandatory=$True, Position=7,HelpMessage = "LUN Group ID",ParameterSetName='Default')][int[]]$GroupID = $null,
	[PARAMETER(Mandatory=$False,Position=8,HelpMessage = "Do not disassociate LUN with LUN Group, only print message",ParameterSetName='Default')][switch]$WhatIf
  )
  $RetVal = @()
 
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
    
	foreach ($CurrentLUNID in $LUNID) {
      if ($WhatIf) {
	    $LUNName =  (Get-OceanStorLUN -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $true -Id $CurrentLUNID).NAME
      }
	  
      foreach ($CurrentGroupId in $GroupID) {
        # ID - Group Id, ASSOCIATEOBJID - LUN Id, ASSOCIATEOBJTYPE=11 - remove LUN (not snapshot)
	    $URI = $RESTURI  + 'lungroup/associate?ID=' + $CurrentGroupId + '&ASSOCIATEOBJTYPE=11&ASSOCIATEOBJID=' + $CurrentLUNID
	
	    if ($WhatIf) {
	      $LUNGroupName = (Get-OceanStorLUNGroup -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $true -Id $CurrentGroupId).NAME
	      write-host "WhatIf (Remove-OceanStorLUNFromLUNGroup): Removing LUN $($LUNName)/$($CurrentLUNID) from LUN Group $($LUNGroupName)/$($CurrentGroupId)" -foreground "Yellow"
	    }
	    else {
          $result = Invoke-RestMethod -Method "Delete" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
		
          if ($result) {
		    $result.data | Add-Member -NotePropertyName 'LUNID' -NotePropertyValue "$($CurrentLUNID)"
		    $result.data | Add-Member -NotePropertyName 'GroupID' -NotePropertyValue "$($CurrentGroupId)"
		  }
		
          if ($result -and ($result.error.code -eq 0)) {
	        $RetVal += $result		  
          }
          else {
		    $RetVal += $result
	        if (-not $Silent) {
	          write-host "ERROR (Remove-OceanStorLUNFromLUNGroup -LUNID $($CurrentLUNID) -GroupID $($CurrentGroupId)): $($result.error.code); $($result.error.description)" -foreground "Red"
	        }
          }		
	    }
	  } #foreach ($CurrentGroupId in $GroupID)
	} #foreach ($CurrentLUNID in $LUNID) {
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}

