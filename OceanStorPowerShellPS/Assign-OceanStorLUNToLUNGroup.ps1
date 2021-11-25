Function Assign-OceanStorLUNToLUNGroup {
  [CmdletBinding(DefaultParameterSetName="LUNName")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='LUNName')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='LUNName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='LUNName')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='LUNName')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='LUNName')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='LUNName')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='LUNName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN name",ParameterSetName='LUNName')][Parameter(ValueFromRemainingArguments=$true)][String]$LUNName = $null,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN Group name",ParameterSetName='LUNName')][Parameter(ValueFromRemainingArguments=$true)][String[]]$GroupName = $null
    # set Name="Testname", so LUN "Testname-boot" is associated with LUN Group "Testname"
 )
  $RetVal = $null
  
  Fix-OceanStorConnection

  # Get LUN Groups and mapping views needed to associate
  $LUNGroups   = Get-OceanStorLUNGroup    -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True | where {$GroupName.ToUpper() -contains $_.NAME.ToUpper()}
  $LUNs        = Get-OceanStorLUN         -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True -Name $LUNName

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

	$URI = $RESTURI  + "lungroup/associate"

    $RetVal = @() 

	$ProcessedLUNGroup = 0
    foreach ($CurrentName in $GroupName) {
      if (-not $Silent) {
        $PercentCompletedLUNGroup = [math]::Floor($ProcessedLUNGroup / $GroupName.Count * 100)
	    Write-Progress -Activity "Associating LUN Groups" -CurrentOperation "$($CurrentName)" -PercentComplete $PercentCompletedLUNGroup
	  }
	  $CurrentLUNGroup = $LUNGroups | where {$_.NAME.ToUpper() -eq $CurrentName.ToUpper()}	  
      if (-not ( $CurrentLUNGroup )) {
	    # No actual LUN Group found
		if (-not $Silent) {
		  write-host "ERROR (Assign-OceanStorLUNToLUNGroup): LUN group $($CurrentName) not found - skipping association" -foreground "Red"
		}
	  }
	  else {
	    # LUN group found, let's check LUN	
		$CurrentLUN = $LUNs
		if (-not ( $CurrentLUN )) {
		  if (-not $Silent) {
		    write-host "ERROR (Assign-OceanStorLUNToLUNGroup): LUN $($CurrentBootLUNName) not found - skipping association" -foreground "Red"
		  }
        }
		else {
		  # LUN group and LUN exist - associate them
		  if ($WhatIf) {
		    write-host "WhatIf (Assign-OceanStorLUNToLUNGroup): Associate LUN Group ($($CurrentName), ID $($CurrentLUNGroup.ID)) and LUN ($($CurrentBootLUNName), ID $($CurrentLUN.ID))" -foreground "Green"
		  }
		  else {
            $LUNGroupAssocForJSON = @{
              ID = $CurrentLUNGroup.ID
		      ASSOCIATEOBJTYPE = 11 # 11 - LUN, 27 -snapshot
		      ASSOCIATEOBJID = $CurrentLUN.ID 
            }
			
            $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $LUNGroupAssocForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
            if ($result -and ($result.error.code -eq 0)) {
              if (-not $Silent) {
			    write-host "LUN $($CurrentBootLUNName) added to LUN Group $($CurrentName)" -foreground "Green"
			  }
              $RetVal += $result.data
            }
            else {
			  if (-not $Silent) {
			    write-host "ERROR (Assign-OceanStorLUNGroupToSimilarMappingView): Failed to associate LUN Group ($($CurrentName), ID $($CurrentLUNGroup.ID)) and LUN ($($CurrentBootLUNName), ID $($CurrentLUN.ID))" -foreground "Red"
              }
            }

		  }
		} # else (-not ( $CurrentLUN ))
	  } # else (-not (  $CurrentLUNGroup  ))
	  $ProcessedLUNGroup += 1
    } #foreach $CurrentName
  
    $URI = $RESTURI  + "sessions"
    $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession  
  }
  
  Return($RetVal)
}

