Function Get-OceanStorSnapshot {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='SnapshotName')][PARAMETER(ParameterSetName='LunID')][PARAMETER(ParameterSetName='SrcLunID')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='SnapshotName')][PARAMETER(ParameterSetName='LunID')][PARAMETER(ParameterSetName='SrcLunID')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='SnapshotName')][PARAMETER(ParameterSetName='LunID')][PARAMETER(ParameterSetName='SrcLunID')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='SnapshotName')][PARAMETER(ParameterSetName='LunID')][PARAMETER(ParameterSetName='SrcLunID')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='SnapshotName')][PARAMETER(ParameterSetName='LunID')][PARAMETER(ParameterSetName='SrcLunID')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='SnapshotName')][PARAMETER(ParameterSetName='LunID')][PARAMETER(ParameterSetName='SrcLunID')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Snapshot name",ParameterSetName='SnapshotName')][String]$Name = $null,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Snapshot ID",ParameterSetName='ID')][int]$ID = $null,
	[PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Parent LUN ID",ParameterSetName='LunID')][int]$LunID = $null,
	[PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Source LUN ID",ParameterSetName='SrcLunID')][int]$SrcLunID = $null
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
      'ID' {  $URI = $RESTURI  + "Snapshot/" + $ID }
	  default { 
	    $URI = $RESTURI  + "Snapshot" 
	  }
    }
	
    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      switch ( $PSCmdlet.ParameterSetName )
      {
        'SnapshotName' {  
	      $RetVal = $result.data | where {$_.Name.ToUpper() -eq $Name.ToUpper()}
		  if ((-not $RetVal) -and (-not $Silent)) {
		    write-host "ERROR (Get-OceanStorSnapshot): Snapshot $($Name) not found" -foreground "Red"
		  }
		}
        'LunID' {  
	      $RetVal = $result.data | where {$_.PARENTID -eq $LunID}
		  if ((-not $RetVal) -and (-not $Silent)) {
		    write-host "ERROR (Get-OceanStorSnapshot): Snapshot with parent LUN ID $($LunID) not found" -foreground "Red"
		  }
		}
        'SrcLunID' {  
	      $RetVal = $result.data | where {$_.SOURCELUNID -eq $LunID}
		  if ((-not $RetVal) -and (-not $Silent)) {
		    write-host "ERROR (Get-OceanStorSnapshot): Snapshot with Source LUN ID $($LunID) not found" -foreground "Red"
		  }
		}
	    default { 
	      $RetVal = $result.data 
	    }
      }		
    }
    else {
      $RetVal = $null
	  if (-not $Silent) {
	    write-host "ERROR (Get-OceanStorSnapshot): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}

