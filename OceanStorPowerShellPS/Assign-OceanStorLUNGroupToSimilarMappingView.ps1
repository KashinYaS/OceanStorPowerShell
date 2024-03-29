Function Assign-OceanStorLUNGroupToSimilarMappingView {
  [CmdletBinding(DefaultParameterSetName="LUNGroupName")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='LUNGroupName')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='LUNGroupName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='LUNGroupName')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='LUNGroupName')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='LUNGroupName')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='LUNGroupName')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='LUNGroupName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN Group and Mapping view name",ParameterSetName='LUNGroupName')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
  )
  $RetVal = $null
 
  Fix-OceanStorConnection

  # Get LUN Groups and mapping views needed to associate
  $LUNGroups   = Get-OceanStorLUNGroup    -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True | where {$Name.ToUpper() -contains $_.NAME.ToUpper()}
  $MappingViews = Get-OceanStorMappingView -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True | where {$Name.ToUpper() -contains $_.NAME.ToUpper()}
    
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

	$URI = $RESTURI  + "mappingview/create_associate"

    $RetVal = @() 

	$ProcessedLUNGroup = 0
    foreach ($CurrentName in $Name) {
      if (-not $Silent) {
        $PercentCompletedLUNGroup = [math]::Floor($ProcessedLUNGroup / $Name.Count * 100)
	    Write-Progress -Activity "Adding LUN Groups" -CurrentOperation "$($CurrentName)" -PercentComplete $PercentCompletedLUNGroup
	  }
	  $CurrentLUNGroup = $LUNGroups | where {$_.NAME.ToUpper() -eq $CurrentName.ToUpper()}
      if (-not ( $CurrentLUNGroup )) {
	    # No actual LUN Group found
		if (-not $Silent) {
		  write-host "ERROR (Assign-OceanStorLUNGroupToSimilarMappingView): LUN group $($CurrentName) not found - skipping association" -foreground "Red"
		}
	  }
	  else {
	    # LUN group found, let's check Mapping View
		$CurrentMappingView = $MappingViews | where {$_.NAME.ToUpper() -eq $CurrentName.ToUpper()}
		if (-not ( $CurrentMappingView )) {
		  if (-not $Silent) {
		    write-host "ERROR (Assign-OceanStorLUNGroupToSimilarMappingView): Mapping View $($CurrentName) not found - skipping association" -foreground "Red"
		  }
        }
		else {
		  # LUN group and Mapping View exist - associate them
		  if ($WhatIf) {
		    write-host "WhatIf (Assign-OceanStorLUNGroupToSimilarMappingView): Associate LUN Group ($($CurrentName), ID $($CurrentLUNGroup.ID)) and Mapping View ($($CurrentName), ID $($CurrentMappingView.ID))" -foreground "Green"
		  }
		  else {
            $MappingViewAssocForJSON = @{
              ID = $CurrentMappingView.ID
		      ASSOCIATEOBJTYPE = 256
		      ASSOCIATEOBJID = $CurrentLUNGroup.ID
            }
	        # ASSOCIATEOBJTYPE: 14 - Host group, 256 - LUN group, 257 - Port group
            $result = Invoke-RestMethod -Method "Put" -Uri $URI -Body (ConvertTo-Json $MappingViewAssocForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
            if ($result -and ($result.error.code -eq 0)) {
              if (-not $Silent) {
			    write-host "LUN Group ($($CurrentName), ID $($CurrentLUNGroup.ID)) associated with Mapping View ($($CurrentName), ID $($CurrentMappingView.ID))" -foreground "Green"
			  }
              $RetVal += $result.data
            }
            else {
			  if (-not $Silent) {
			    write-host "ERROR (Assign-OceanStorLUNGroupToSimilarMappingView): Failed to associate LUN Group ($($CurrentName), ID $($CurrentLUNGroup.ID)) and Mapping View ($($CurrentName), ID $($CurrentMappingView.ID)): $($result.error.code); $($result.error.description)" -foreground "Red"
              }
            }

		  }
		} # else (-not ( $CurrentMappingView ))
	  } # else (-not (  $CurrentLUNGroup  ))
	  $ProcessedLUNGroup += 1
    } #foreach $CurrentName
  
    $URI = $RESTURI  + "sessions"
    $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession  
  }
  
  Return($RetVal)
}

