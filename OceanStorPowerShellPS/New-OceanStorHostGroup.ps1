Function New-OceanStorHostGroup {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][PARAMETER(ParameterSetName='GroupName')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][PARAMETER(ParameterSetName='GroupName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][PARAMETER(ParameterSetName='GroupName')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][PARAMETER(ParameterSetName='GroupName')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][PARAMETER(ParameterSetName='GroupName')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][PARAMETER(ParameterSetName='GroupName')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][PARAMETER(ParameterSetName='GroupName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=7,HelpMessage = "Host group(s) names as array of OceanStor HostGroup Objects",ParameterSetName='default')][Parameter(ValueFromRemainingArguments=$true)][Object[]]$StorageHostGroups = $null,
    [PARAMETER(Mandatory=$True, Position=7,HelpMessage = "Host group(s) names as array of strings",ParameterSetName='GroupName')][Parameter(ValueFromRemainingArguments=$true)][string[]]$Name = $null
  )
  $RetVal = $null
  
  Fix-OceanStorConnection

  $body = @{username = "$($Username)";password = "$($Password)";scope = $Scope}

  $BaseRESTURI = "https://" + $OceanStor + ":" + $Port + "/deviceManager/rest/"
  $SessionURI = $BaseRESTURI  + "xxxxx/sessions"

  # --- Name preprocessing ---
  # $Name can only be an array of strings
  # $StorageHostGroups can be a mixed array of groups fetched from another OceanStor and Strings
  # So furthermore any string should be convert to an object with Name field and there is no need to especialy treat GroupName parameter set.
  if ($PSCmdlet.ParameterSetName -eq 'GroupName') {
    $StorageHostGroups = $Name
  }

  $TMPStorageHostGroups = @()
  foreach ($StorageHostGroup in $StorageHostGroups) {
    if ($StorageHostGroup -is [String]) {
	  $StorageHostGroupObject =  New-Object PSObject -Property @{
        NAME = $StorageHostGroup
	  }
	  $TMPStorageHostGroups += $StorageHostGroupObject
	}
	else {
	  $TMPStorageHostGroups += $StorageHostGroup
	}
  }
  $StorageHostGroups = $TMPStorageHostGroups

  # --- OceanStor modification section, one big session, cause no pauses in modification procedure intended ---
  $logonsession = Invoke-RestMethod -Method "Post" -Uri $SessionURI -Body (ConvertTo-Json $body) -SessionVariable WebSession

  if ($logonsession -and ($logonsession.error.code -eq 0)) {
    $sessionid = $logonsession.data.deviceid
    $iBaseToken = $logonsession.data.iBaseToken
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $($Username),'''$($Password''')))
    $header = @{Authorization = "Basic $base64AuthInfo";iBaseToken = $iBaseToken}
    $RESTURI = $BaseRESTURI  + $sessionid +"/"

    $UserCredentials = New-Object System.Management.Automation.PsCredential("$($Username)",$(ConvertTo-SecureString -String "$($Password)" -AsPlainText -force))
  
    # --- host group adding
    if (-not $Silent) {
	  Write-Progress  -Activity "Adding host group(s)" -CurrentOperation "Getting existing host groups" -PercentComplete 10
	}
    $URI = $RESTURI  + "hostgroup"
    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      $OceanStorHostGroups = $result.data
    }
    else {
      $OceanStorHostGroups = @()
    }

    #$AssocURI = $RESTURI  + "hostgroup/associate"
  
    $ProcessedHostGroups = 0
    ForEach ($StorageHostGroup in $StorageHostGroups) {
      $GroupName = $StorageHostGroup.Name
      $PercentCompletedHostGroups = [math]::Floor($ProcessedHostGroups / $StorageHostGroups.Count * 90) + 10
      if (-not $Silent) {
	    Write-Progress  -Activity "Adding host group(s)" -CurrentOperation "Processing $($GroupName)" -PercentComplete $PercentCompletedHostGroups 
	  }
      $ActualHostGroup = $OceanStorHostGroups | where {$_.Name.ToUpper() -eq $GroupName.ToUpper()}

      if ($ActualHostGroup) {
        if (-not $Silent) { write-host "Group $($GroupName) already exists" -foreground "Green" }
      }
      else {
        $GroupForJSON = @{
          NAME = $GroupName
        }
		if ($WhatIf) {
		   write-host "WhatIf (New-OceanStorHostGroup): Add host group $($GroupName)" -foreground "Green" 
		}
		else {
          $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $GroupForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
            if (-not $Silent) { write-host "Group $($GroupName) added" -foreground "Green" }
            $ActualHostGroup = $result.data        
          }
          else {
            if (-not $Silent) { write-host "ERROR (New-OceanStorHostGroup): Failed to add Group $($GroupName): $($result.error.description)" -foreground "Red" }
          }
		}
      }
    	  
    $ProcessedHostGroups += 1  
  }
  # --- end host  adding
  
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
}
# --- OceanStor modification section, one big session end ---


  Return($RetVal)

}

