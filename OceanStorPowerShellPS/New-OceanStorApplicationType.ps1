Function New-OceanStorApplicationType {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Request Size (0=4 KB, 1=8 KB, 2=16 KB, 3=32 KB, 4=64 KB, 5= more than 64 KB)",ParameterSetName='default')][int]$RequestSize=5,
    [PARAMETER(Mandatory=$False,Position=7,HelpMessage = "Compression",ParameterSetName='default')][switch]$Compression,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "Deduplication",ParameterSetName='default')][switch]$Deduplication,
    [PARAMETER(Mandatory=$True, Position=9,HelpMessage = "Application Type Name",ParameterSetName='default')][Parameter(ValueFromRemainingArguments=$true)][String]$Name = $null
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
  
  	  $URI = $RESTURI  + "workload_type"
  
      $RetVal = $null 
  
        if (-not $Silent) {
          write-host "INFO (New-OceanStorApplicationType): Creating Application Type $($Name)" -foreground "Green"
  	    }
        
		if ($Compression)   { $EnableCompress = 'true' } else { EnableCompress = 'false' }
		if ($Deduplication) { $EnableDedup = 'true' }    else { $EnableDedup = 'false' }
		
  	    $AppTypeForJSON = @{
          NAME = $Name
		  BLOCKSIZE = $RequestSize
  		  ENABLECOMPRESS = $EnableCompress
  	      ENABLEDEDUP = $EnableDedup
        }
  
        if (-not $WhatIf) {	
          $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $AppTypeForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
		  if ($result -and ($result.error.code -eq 0)) {
  	        $RetVal = $result.data		
          }
          else {
            $RetVal = $null
  	        if (-not $Silent) {
  	          write-host "ERROR (New-OceanStorApplicationType): $($result.error.code); $($result.error.description)" -foreground "Red"
  	        }
          }
  	    }
  	    else {
  	        write-host "WhatIf (New-OceanStorApplicationType): Create Application Type $($Name) " -foreground "Green"  
  	    }
      
	  $URI = $RESTURI  + "sessions"
      $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    
    } # if ($logonsession -and ($logonsession.error.code -eq 0)) {

    Return($RetVal)

}

