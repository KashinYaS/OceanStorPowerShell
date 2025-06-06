Function Get-OceanStorHost {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][bool]$Silent=$true,
	[PARAMETER(Mandatory=$False,Position=6,HelpMessage = "AddCustomProps - add custom properties (WWNs etc.)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][switch]$AddCustomProps,	    
	[PARAMETER(Mandatory=$True,Position=7,HelpMessage = "Host name",ParameterSetName='Hostname')][String[]]$Name = $null,
    [PARAMETER(Mandatory=$True,Position=7,HelpMessage = "Host ID",ParameterSetName='ID')][int[]]$ID = $null
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
      'ID' {
		if ($ID.Count -eq 1) {
		  $URI = $RESTURI  + "host/" + $ID
		}`
		else {
		  $URI = $RESTURI  + "host"
		}
      }
	  default { 
	    $URI = $RESTURI  + "host"
	  }
    }
	
    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      switch ( $PSCmdlet.ParameterSetName )
      {
        'Hostname' { 
	      $RetVal = $result.data | where {$Name.ToUpper() -contains $_.Name.ToUpper()}
		  if ((-not $RetVal) -and (-not $Silent)) {
		    write-host "ERROR (Get-OceanStorHosts): Host(s) $($Name) not found" -foreground "Red"
		  }		  
		}
		'ID' {
		  if ($ID.Count -eq 1) {
			$RetVal = $result.data
		  }`
          else {
			$RetVal = $result.data | where {$ID -contains $_.ID}
		    if ((-not $RetVal) -and (-not $Silent)) {
		      write-host "ERROR (Get-OceanStorHosts): Host(s) with ID(s) $($ID) not found" -foreground "Red"
		    }					
		  }			  
		}
	    default { 
	      $RetVal = $result.data	
	    }
      }
	  
	  if ($AddCustomProps) {
		$CustomRetVal = @()
	    $FCInitiators =  Get-OceanStorFCInitiator -OceanStor "$OceanStor" -Username "$Username" -Password "$Password" -Scope $Scope -Port "$Port" -Silent $true
		if ($FCInitiators) {
		  foreach ($OceanStorHost in $RetVal) {
            $HostFCInitiators = $FCInitiators | where {$_.ParentID -eq $OceanStorHost.ID}
			if ($HostFCInitiators) {
		      $SortedIDs = ($HostFCInitiators | Sort ID).ID
			  if ($SortedIDs[0]) {
			    $OceanStorHost | Add-Member -Name "FirstpWWN" -MemberType Noteproperty -Value "$($SortedIDs[0])"
			  }
			  if ($SortedIDs[1]) {
			    $OceanStorHost | Add-Member -Name "SecondpWWN" -MemberType Noteproperty -Value "$($SortedIDs[1])"
			  }
		    }
            $CustomRetVal += $OceanStorHost 
		  }
	      $RetVal = $CustomRetVal
		}
	  }
	  
    }
    else {
      $RetVal = $null
	  if (-not $Silent) {
	    write-host "ERROR (Get-OceanStorHosts): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}

