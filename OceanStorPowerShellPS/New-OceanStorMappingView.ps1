Function New-OceanStorMappingView {
  [CmdletBinding(DefaultParameterSetName="MappingViewName")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='MappingViewName')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='MappingViewName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='MappingViewName')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='MappingViewName')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='MappingViewName')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='MappingViewName')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='MappingViewName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$False,Position=7,HelpMessage = "Application Type (0 - other, 1 - oracle, 2 - exchange, 3 - sqlserver, 4 - vmware, 5 - hyper-V)",ParameterSetName='MappingViewName')][int]$AppType=0,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Mapping View name(s)",ParameterSetName='MappingViewName')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
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

	$URI = $RESTURI  + "mappingview"

    # --- getting existing mapping views
    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      $OceanStorMappingViews = $result.data
    }
    else {
      $OceanStorMappingViews = $null
    }
    	
	$RetVal = @() 

	$ProcessedMappingView = 0
    foreach ($CurrentName in $Name) {
      if (-not $Silent) {
        $PercentCompletedMappingView = [math]::Floor($ProcessedMappingView / $Name.Count * 100)
	     Write-Progress -Activity "Adding Mapping View" -CurrentOperation "$($CurrentName)" -PercentComplete $PercentCompletedMappingView
	  }
    
      $ActualMappingView = $OceanStorMappingViews | where {$_.Name.ToUpper() -eq $CurrentName.ToUpper()}
      if ($ActualMappingView) {
        if (-not $Silent) { write-host "Mapping view $($CurrentName) exists - skipping creation" -foreground "Yellow" }
      }
      else {	  
	    $MappingViewForJSON = @{
          NAME = $CurrentName
        }

        if (-not $WhatIf) {	
          $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $MappingViewForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
	        $RetVal += $result.data		
          }
          else {
            $RetVal += $null
	        if (-not $Silent) {
	          write-host "ERROR (New-OceanStorMappingView): $($result.error.code); $($result.error.description)" -foreground "Red"
	        }
          }
	    }
	    else {
	      write-host "WhatIf (New-OceanStorMappingView): Create LUN Group with name $($CurrentName) and application type $($AppType)" -foreground "Green"
	    }
	  }
        $ProcessedMappingView += 1
    }
  
  } #foreach $CurrentName
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}

