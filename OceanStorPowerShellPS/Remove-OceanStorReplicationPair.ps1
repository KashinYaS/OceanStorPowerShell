Function Remove-OceanStorReplicationPair {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True,  Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][String]$OceanStor,
    [PARAMETER(Mandatory=$False, Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True,  Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][String]$Username,
    [PARAMETER(Mandatory=$True,  Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][String]$Password,
    [PARAMETER(Mandatory=$False, Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][int]$Scope=0,
    [PARAMETER(Mandatory=$False, Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$False, Position=6,HelpMessage = "ReplicationPair ID",ParameterSetName='ID')][Parameter(ValueFromRemainingArguments=$true)][String[]]$ID = $null,
	[PARAMETER(Mandatory=$False, Position=6,HelpMessage = "Replicated LUN ID",ParameterSetName='LunID')][Parameter(ValueFromRemainingArguments=$true)][String[]]$LunID = $null,
	[PARAMETER(Mandatory=$False, Position=7,HelpMessage = "Do not remove Replication Pair, only print message",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][switch]$WhatIf,
	[PARAMETER(Mandatory=$False, Position=8,HelpMessage = "Force delete. Specify to delete ALL Replication pairs",ParameterSetName='Default')][switch]$Force
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

    if ( ($PSCmdlet.ParameterSetName -eq 'default') -and (-not $Force)) {
      write-host "ERROR (Remove-OceanStorReplicationPair) - No Replication pair specified. Use -Force parameter to delete ALL Replication pairs" -foreground "Red"
    }
    else {
      switch ( $PSCmdlet.ParameterSetName )
      {
        'ID'    {
          $RPs = Get-OceanStorReplicationPair -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $true -ID $ID 
	    }
        'LunID'    {
          $RPs = Get-OceanStorReplicationPair -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $true -LunID $LunID 
	    }
	    default { 
	     $RPs = Get-OceanStorReplicationPair -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $true
	    }
      }
      if (-not $RPs) {
        write-host "ERROR (Remove-OceanStorReplicationPair) - No Replication pair found using parameters specified" -foreground "Red"
	  }
      else {
	    if (-not $Silent) {
	      if ($RPs.Count -gt 1) {
		    write-host "INFO (Remove-OceanStorReplicationPair) - Found $($RPs.Count) Replication pairs to delete" -foreground "Green"
		  }
		  else {
		    write-host "INFO (Remove-OceanStorReplicationPair) - Found Replication pair $($RPs.ID)/$($RPs.LOCALRESNAME) to delete" -foreground "Green"
		  }
		}
		foreach ($RP in $RPs) {
		  if ($WhatIf) {
			write-host "WhatIf (Remove-OceanStorReplicationPair): Removing Replication Pair ID $($RP.ID) (Local LUN: $($RP.LOCALRESNAME)/$($RP.LOCALRESID), Remote LUN: $($RP.REMOTERESNAME)/$($RP.REMOTERESID) at $($RP.REMOTEDEVICENAME))" -foreground "Yellow"
		  }
		  else {
			switch ($RP.RUNNINGSTATUS) {
			  {1,23 -eq $_ } {
				  # Normal or Synchronizing - need to split before delete
				  if (-not $Silent) {
				    write-host "INFO (Remove-OceanStorReplicationPair) - Splitting Replication pair $($RP.ID)/$($RP.LOCALRESNAME)" -foreground "Green"
				  }
                  
				  $RPForJSON = $RP | Select ID
			      $URI = $RESTURI  + "REPLICATIONPAIR/split"
			      $result = Invoke-RestMethod -Method "Put" $URI -Body (ConvertTo-Json $RPForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
                  if ($result -and ($result.error.code -eq 0)) {
				    $RP.RUNNINGSTATUS = 26
				  }
			      else {
			        write-host "ERROR (Remove-OceanStorReplicationPair): Cannot split Replication pair $($RP.ID)/$($RP.LOCALRESNAME) before delete ($($result.error.code); $($result.error.description))" -foreground "Red"
			      }				  
			    }
			  26 {
				  # Already Split up
				  if (-not $Silent) {
				    write-host "INFO (Remove-OceanStorReplicationPair) - Replication pair $($RP.ID)/$($RP.LOCALRESNAME) already splitted up - skipping splitting" -foreground "Green"
				  }
			    }
			  default {
			    write-host "ERROR (Remove-OceanStorReplicationPair): Replication Pair ID $($RP.ID) (Local LUN: $($RP.LOCALRESNAME)/$($RP.LOCALRESID))state is not Normal,Synchronizing or Split state - cancelling delete" -foreground "Red"
			  }
			}
			
			
		    if ($RP.RUNNINGSTATUS -eq 26) {
			  $URI = $RESTURI  + "REPLICATIONPAIR/" + $($RP.ID)
			
			  $result = Invoke-RestMethod -Method "Delete" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
			 
              if ($result -and ($result.error.code -eq 0)) {
	            [array]$RetVal += $result
				if (-not $Silent) {
				  write-host "INFO (Remove-OceanStorReplicationPair) - Replication pair $($RP.ID)/$($RP.LOCALRESNAME) Deleted" -foreground "Green" 
				}
              }
              else {
		        [array]$RetVal += $result
	            if (-not $Silent) {
	              write-host "ERROR (Remove-OceanStorReplicationPair): $($result.error.code); $($result.error.description)" -foreground "Red"
	            }
              }		
			 
		    }
			
		  }
		}
	  }		  
    }	   

  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}

