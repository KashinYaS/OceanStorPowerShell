Function Assign-OceanStorHostToHostGroup {
  [CmdletBinding(DefaultParameterSetName="HostGroupName")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='HostGroupName')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='HostGroupName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='HostGroupName')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='HostGroupName')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='HostGroupName')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='HostGroupName')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='HostGroupName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Host Group name",ParameterSetName='HostGroupName')][String[]]$HostGroupName = $null,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Host name(s)",ParameterSetName='HostGroupName')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
  )
  $RetVal = $null
 
  # --- prepare to connect with TLS 1.2 and ignore self-signed certificate of OceanStor ---
  [Net.ServicePointManager]::SecurityProtocol =[Net.SecurityProtocolType]::Tls12

  Fix-OceanStorConnection

  # Get LUN Groups and mapping views needed to associate
  $Hosts       = Get-OceanStorHost      -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True | where {$Name.ToUpper() -contains $_.NAME.ToUpper()}
  $HostGroup   = Get-OceanStorHostGroup -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True | where {$HostGroupName.ToUpper() -contains $_.NAME.ToUpper()} | Select -First 1
    
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

	$URI = $RESTURI  + "hostgroup/associate"

	$RetVal = @() 

	$ProcessedLUNGroup = 0
	foreach ($CurrentName in $Name) {
	  if (-not $Silent) {
		$PercentCompletedLUNGroup = [math]::Floor($ProcessedLUNGroup / $Name.Count * 100)
		Write-Progress -Activity "Adding Host to Host Group" -CurrentOperation "$($CurrentName)" -PercentComplete $PercentCompletedLUNGroup
	  }
	  $CurrentHost = $Hosts | where {$_.NAME.ToUpper() -eq $CurrentName.ToUpper()}
	  if (-not ( $CurrentHost )) {
		# No actual Host found
		if (-not $Silent) {
		  write-host "ERROR (Assign-OceanStorHostToHostGroup): Host $($CurrentName) not found - skipping association" -foreground "Red"
		}
	  }
	  else {
		# Host found, let's check Host Group
		$CurrentHostGroup = $HostGroup
		if (-not ( $CurrentHostGroup )) {
		  if (-not $Silent) {
			write-host "ERROR (Assign-OceanStorHostToHostGroup): Host Group $($CurrentName) not found - skipping association" -foreground "Red"
		  }
		}
		else {
	      if (-not $Silent) {
		    Write-Progress -Activity "Adding Host to Host Group" -CurrentOperation "$($CurrentHost.Name) -> $($CurrentHostGroup.Name)" -PercentComplete $PercentCompletedLUNGroup
		  }
			
		  # Host and Host Group both exist - associate them
		  if ($WhatIf) {
			write-host "WhatIf (Assign-OceanStorHostToHostGroup): Associate Host ($($CurrentHost.Name), ID $($CurrentHost.ID)) and Host Group ($($CurrentHostGroup.Name), ID $($CurrentHostGroup.ID))" -foreground "Green"
		  }
		  else {
			$HostAssociationForJSON = @{
			  ID = $CurrentHostGroup.ID
			  ASSOCIATEOBJTYPE = 21
			  ASSOCIATEOBJID = $CurrentHost.ID
			}
			# ASSOCIATEOBJTYPE: 14 - Host group, 256 - LUN group, 257 - Port group, 21 - Host
			$result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $HostAssociationForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
			if ($result -and ($result.error.code -eq 0)) {
			  if (-not $Silent) {
				write-host "Host ($($CurrentHost.Name), ID $($CurrentHost.ID)) succesfully associated with Host Group ($($CurrentHostGroup.Name), ID $($CurrentHostGroup.ID))" -foreground "Green"
			  }
			  $RetVal += $result.data
			}
			else {
			  if (-not $Silent) {
				write-host "ERROR (Assign-OceanStorHostToHostGroup): Failed to associate Host ($($CurrentHost.Name), ID $($CurrentHost.ID)) and Host Group ($($CurrentHostGroup.Name), ID $($CurrentHostGroup.ID)): $($result.error.description)" -foreground "Red"
			  }
			}
		  }
		} # else (-not ( $CurrentHostGroup ))
	  } # else (-not (  $CurrentHost  ))
	  $ProcessedLUNGroup += 1
	} #foreach $CurrentName
  
	$URI = $RESTURI  + "sessions"
	$SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession  
  }
  
  Return($RetVal)
}

