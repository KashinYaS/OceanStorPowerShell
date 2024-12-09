Function Get-OceanStorReplicationPair {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True,  Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][String]$OceanStor,
    [PARAMETER(Mandatory=$False, Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True,  Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][String]$Username,
    [PARAMETER(Mandatory=$True,  Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][String]$Password,
    [PARAMETER(Mandatory=$False, Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][int]$Scope=0,
    [PARAMETER(Mandatory=$False, Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][bool]$Silent=$true,
	[PARAMETER(Mandatory=$False, Position=6,HelpMessage = "AddCustomProps - add custom properties (LUN WWN etc.)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LunID')][switch]$AddCustomProps,
    [PARAMETER(Mandatory=$False, Position=7,HelpMessage = "ReplicationPair ID",ParameterSetName='ID')][Parameter(ValueFromRemainingArguments=$true)][String[]]$ID = $null,
	[PARAMETER(Mandatory=$False, Position=7,HelpMessage = "Replicated LUN ID",ParameterSetName='LunID')][Parameter(ValueFromRemainingArguments=$true)][String[]]$LunID = $null
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
      'ID'    {
	    if ( $ID.Count -eq 1 ) {
	      $URI = $RESTURI  + "REPLICATIONPAIR/" + $ID
	    }
	    else {
          $URI = $RESTURI  + "REPLICATIONPAIR"
	    }
	  }
	  default { 
	    $URI = $RESTURI  + "REPLICATIONPAIR"
	  }
    }
	
    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      switch ( $PSCmdlet.ParameterSetName )
      {
        'ID' {
	       if ( $ID.Count -eq 1 ) { 
	         $RetVal = $result.data		
	       }
	       else { # several objects specified - need to select some of them
	         $RetVal = $result.data | where { $ID -contains $_.ID }
	       }		  
		}
        'LunID' {
	       if ( $LunID.Count -eq 1 ) { 
	         $RetVal = $result.data	| where {($_.LOCALRESTYPE -eq 11) -and ($_.LOCALRESID -eq $LunID)}	
	       }
	       else { # several objects specified - need to select some of them
	         $RetVal = $result.data | where {($_.LOCALRESTYPE -eq 11) -and ($LunID -contains $_.LOCALRESID)}
	       }		  
		}
	    default { 
	      $RetVal = $result.data 
	    }
      }
	  
	  if ($AddCustomProps -and $RetVal) {
	    $LUNs = Get-OceanStorLUN -OceanStor "$OceanStor" -Port "$Port" -Username "$Username" -Password "$Password" -Scope $Scope -AddCustomProps -Silent $true
		
		Add-Type -AssemblyName System.Web
		
		foreach ($RP in $RetVal) {
          $LUN = $LUNs | where {$_.ID -eq $RP.LOCALRESID}
          $RP | Add-Member -NotePropertyName 'LOCALRESWWN' -NotePropertyValue "$($LUN.WWN)"
		  $LUNDescription = [System.Web.HttpUtility]::HtmlDecode($LUN.Description)
		  $RP | Add-Member -NotePropertyName 'LOCALRESDESCRIPTION' -NotePropertyValue "$($LUNDescription)"
		}
		
	  }
				
    }
    else {
      $RetVal = $null
	  if (-not $Silent) {
	    write-host "ERROR (Get-OceanStorReplicationPair): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}

