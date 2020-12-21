Function New-OceanStorReplicationPair {
  [CmdletBinding(DefaultParameterSetName="LUN_ID")]
  PARAM (
    [PARAMETER(Mandatory=$True,  Position=0, HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='LUN_ID')][String]$OceanStor,
    [PARAMETER(Mandatory=$False, Position=1, HelpMessage = "Port",ParameterSetName='LUN_ID')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True,  Position=2, HelpMessage = "Username",ParameterSetName='LUN_ID')][String]$Username,
    [PARAMETER(Mandatory=$True,  Position=3, HelpMessage = "Password",ParameterSetName='LUN_ID')][String]$Password,
    [PARAMETER(Mandatory=$False, Position=4, HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='LUN_ID')][int]$Scope=0,
    [PARAMETER(Mandatory=$False, Position=13,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='LUN_ID')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False, Position=5, HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='LUN_ID')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True,  Position=6, HelpMessage = "Local LUN ID",ParameterSetName='LUN_ID')][int]$LocalLUNID = $null,
    [PARAMETER(Mandatory=$True,  Position=7, HelpMessage = "Remote Device ID (use Get-OceanStorRemoteDevice)",ParameterSetName='LUN_ID')][int]$RemoteDeviceID = $null,
    [PARAMETER(Mandatory=$True,  Position=8, HelpMessage = "Remote LUN ID",ParameterSetName='LUN_ID')][int]$RemoteLUNID = $null,
    [PARAMETER(Mandatory=$False, Position=9, HelpMessage = "Synchronization type (1: manual, 2: timed wait after synchronization begins, 3: timed wait after synchronization end)",ParameterSetName='LUN_ID')][int]$SyncType = 1,	
    [PARAMETER(Mandatory=$False, Position=10,HelpMessage = "Synchronization speed (1: low, 2: medium, 3: high, 4: highest)",ParameterSetName='LUN_ID')][int]$SyncSpeed = 2,	
    [PARAMETER(Mandatory=$False, Position=11,HelpMessage = "Synchronization interval (minutes)",ParameterSetName='LUN_ID')][int]$SyncInterval = 60,	
    [PARAMETER(Mandatory=$False, Position=12, HelpMessage = "Enable compression",ParameterSetName='LUN_ID')][bool]$Compress=$true
	)
  $RetVal = $null
 
  Fix-OceanStorConnection
  
  if (-not (($LocalLUNID -ge 0) -and ($RemoteDeviceID -ge 0) -and ($RemoteLUNID -ge 0))) {
    if (-not $Silent) {
      write-host "ERROR (New-OceanStorReplicationPair): Not enough parameters specified)" -foreground "Red"
    }
  }
  else {  
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
  
  	  $URI = $RESTURI  + "REPLICATIONPAIR"
  
      $RetVal = @()
	           
  	  $RemoteAllocPairForJSON = @{
          LOCALRESID = $LocalLUNID
		  LOCALRESTYPE = 11 # 11 - LUN, 40 File system
		  REMOTEDEVICEID = $RemoteDeviceID
		  REMOTERESID = $RemoteLUNID		  
		  SYNCHRONIZETYPE = $SyncType # 1: manual, 2: timed wait after synchronization begins, 3: timed wait after synchronization end
		  SPEED = $SyncSpeed # 1: low, 2: medium, 3: high, 4: highest
		  TIMINGVAL = $SyncInterval * 60
		  REPLICATIONMODEL = 2 # 1: synchronous replication, 2: asynchronous replication
		  ENABLECOMPRESS = $Compress
     }
	 
	 
      if (-not $WhatIf) {	
          $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $RemoteAllocPairForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
  	        $RetVal += $result.data		
          }
          else {
            $RetVal += $null
  	        if (-not $Silent) {
  	          write-host "ERROR (New-OceanStorReplicationPair): $($result.error.code); $($result.error.description)" -foreground "Red"
  	        }
          }
  	  }
  	  else {
  	    write-host "WhatIf (New-OceanStorReplicationPair):: Create Replicarion pair of Local LUN $($LocalLUNID) with Device $($RemoteDeviceID) remote LUN $($RemoteLUNID) " -foreground "Green"
  	  }
     
	  $URI = $RESTURI  + "sessions"
      $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    
    } # if ($logonsession -and ($logonsession.error.code -eq 0)) {
    Return($RetVal)
  } # if ((-not $StoragePool) -or ($StoragePool.Count -gt 1)) {
}

