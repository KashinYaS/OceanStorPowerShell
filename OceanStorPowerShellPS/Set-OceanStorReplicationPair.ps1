Function Set-OceanStorReplicationPair {
  [CmdletBinding(DefaultParameterSetName="ReplicationPair")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='ReplicationPair')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='ReplicationPair')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='ReplicationPair')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='ReplicationPair')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='ReplicationPair')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='ReplicationPair')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='ReplicationPair')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Is compression enabled",ParameterSetName='ReplicationPair')][bool]$EnableCompress=$false,	
    [PARAMETER(Mandatory=$False,Position=9,HelpMessage = "Replication pair ID",ParameterSetName='ReplicationPair')][Parameter(ValueFromRemainingArguments=$true)][String[]]$ID = $null
  )
  $RetVal = $null
 
  Fix-OceanStorConnection
  
  #write-host $ID
  
  $ReplicationPairs = Get-OceanStorReplicationPair -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True -ID $ID

  if (-not $ReplicationPairs) {
    if (-not $Silent) {
      write-host "ERROR (Set-OceanStorReplicationPair): Wrong ID specified $($ID))" -foreground "Red"
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
  
  	  $ProcessedReplicationPair = 0
	  
      foreach ($ReplicationPair in $ReplicationPairs) {
	    $CurrentID = $ReplicationPair.ID
        if (-not $Silent) {
          $PercentCompletedLUN = [math]::Floor($ProcessedReplicationPair / $ReplicationPairs.Count * 100)
  	      Write-Progress -Activity "Modifying Replication pair" -CurrentOperation "$($CurrentID)" -PercentComplete $PercentCompletedLUN
  	    }
        
  	    $LUNForJSON = @{
          ID = $CurrentID
		  ENABLECOMPRESS = $EnableCompress
        }
  
        $URI = $RESTURI  + "REPLICATIONPAIR/" + $CurrentID
  
        if (-not $WhatIf) {	
          $result = Invoke-RestMethod -Method "Put" -Uri $URI -Body (ConvertTo-Json $LUNForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
  	        $RetVal += $result.data		
          }
          else {
            $RetVal += $null
  	        if (-not $Silent) {
  	          write-host "ERROR (Set-OceanStorReplicationPair): $($result.error.code); $($result.error.description)" -foreground "Red"
  	        }
          }
  	    }
  	    else {
		    $Modifications = ""
			if ( $EnableCompress ) { $Modifications += "Enabling compression" } else { $Modifications += "Disabling compression"}
  	        write-host "WhatIf (Set-OceanStorReplicationPair): Modify Replication pair with ID $($CurrentID): $($Modifications)" -foreground "Green"	  
  	    }
        $ProcessedReplicationPair += 1    
      } #foreach $CurrentID
      
	  $URI = $RESTURI  + "sessions"
      $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    
    } # if ($logonsession -and ($logonsession.error.code -eq 0)) {
    Return($RetVal)
  } # if ((-not $StoragePool) -or ($StoragePool.Count -gt 1)) {
}

