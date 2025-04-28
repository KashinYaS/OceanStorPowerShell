Function Remove-OceanStorApplicationType {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][PARAMETER(ParameterSetName='Name')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][PARAMETER(ParameterSetName='Name')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][PARAMETER(ParameterSetName='Name')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][PARAMETER(ParameterSetName='Name')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][PARAMETER(ParameterSetName='Name')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][PARAMETER(ParameterSetName='Name')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][PARAMETER(ParameterSetName='Name')][bool]$Silent=$true,	
    [PARAMETER(Mandatory=$True, Position=7,HelpMessage = "Application Type ID",ParameterSetName='default')][Parameter(ValueFromRemainingArguments=$true)][int[]]$ID = $null,	
    [PARAMETER(Mandatory=$True, Position=7,HelpMessage = "Application Type Name",ParameterSetName='Name')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
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

      $CurrentApplicationTypes = Get-OceanStorApplicationType -OceanStor "$OceanStor" -Port $Port -Username "$Username" -Password "$Password" -Scope $Scope -Silent $false

      $ApplicationTypesToDelete = @()
	  
      if ( $PSCmdlet.ParameterSetName -eq 'default') {
		$ApplicationTypesToDelete = $CurrentApplicationTypes | where {$ID -contains $_.ID}
	  }`
	  else {
		$ApplicationTypesToDelete = $CurrentApplicationTypes | where { ($Name -contains $_.Name) -or ($Name -contains [System.Net.WebUtility]::HtmlDecode($_.Name)) }  	
	  }
	  
	  if ($ApplicationTypesToDelete) { 
        
		foreach ($CurrentApplicationTypeToDelete in $ApplicationTypesToDelete) {
			
		  if (-not $Silent) {
            write-host "INFO (Remove-OceanStorApplicationType): Trying to remove Application type $($CurrentApplicationTypeToDelete.Name)/$($CurrentApplicationTypeToDelete.ID)" -foreground "Green"
  	      }
        
          if (-not $WhatIf) {
            $CurrentURI = $URI + '/' + "$($CurrentApplicationTypeToDelete.ID)"	  
            $result = Invoke-RestMethod -Method "Delete" -Uri $CurrentURI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
		    if ($result -and ($result.error.code -eq 0)) {
  	          $RetVal = $result.data		
            }
            else {
              $RetVal = $null
  	          if (-not $Silent) {
  	            write-host "ERROR (Remove-OceanStorApplicationType): $($result.error.code); $($result.error.description)" -foreground "Red"
  	          }
            }
  	      }
  	      else {
  	        write-host "WhatIf (Remove-OceanStorApplicationType): Remove Application Type $($CurrentApplicationTypeToDelete.Name)/$($CurrentApplicationTypeToDelete.ID)" -foreground "Green"  
  	      }

		}
      }`
	  else {
  	    if (-not $Silent) {
  	      if ( $PSCmdlet.ParameterSetName -eq 'default') {
			write-host "ERROR (Remove-OceanStorApplicationType): No Application Type with specified ID(s) $($ID) found" -foreground "Red"
		  }`
		  else {
			write-host "ERROR (Remove-OceanStorApplicationType): No Application Type with specified Name(s) $($Name) found" -foreground "Red"		  
		  }
  	    }	     
	  }
	  $URI = $RESTURI  + "sessions"
      $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession -ErrorAction SilentlyContinue
    
    } # if ($logonsession -and ($logonsession.error.code -eq 0)) {

    Return($RetVal)

}

