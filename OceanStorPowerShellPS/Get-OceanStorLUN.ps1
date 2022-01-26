Function Get-OceanStorLUN {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNName')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNName')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNName')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNName')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN name",ParameterSetName='LUNName')][String[]]$Name = $null,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "LUN ID",ParameterSetName='ID')][int[]]$ID = $null,
	[PARAMETER(Mandatory=$False,Position=7,HelpMessage = "CanDelete - return only LUN(s) that can be deleted",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNName')][switch]$CanDelete
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
	    if ( $ID.Count -eq 1 ) {
	      $URI = $RESTURI  + "lun/" + $ID
	    }
	    else {
          $URI = $RESTURI  + "lun"
	    }
	  }
	  default { 
	    $URI = $RESTURI  + "lun" 
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
			 if ($RetVal) {
			   if ($RetVal.Count -lt $ID.Count) {
			     if (-not $Silent) {
				   $NotFoundLUNIDs = ($ID | where {$RetVal.ID -notcontains $_}) -join ','
		           write-host "WARNING (Get-OceanStorLUN): LUN(s) with ID(s) $($NotFoundLUNIDs) not found" -foreground "Yellow"
		         }
			   }
			 }
			 else {
		       if (-not $Silent) {
		         write-host "ERROR (Get-OceanStorLUN): LUN(s) with ID(s) $($ID -join ',') not found" -foreground "Red"
		       }
             }
	       }		  
		}		  
        'LUNName' {  
	      $RetVal = $result.data | where {$Name.ToUpper() -contains $_.Name.ToUpper()}
		  if ($RetVal) {
			if ($RetVal.Count -lt $Name.Count) {
			  if (-not $Silent) {
			    $NotFoundLUNNames = ($Name | where {$RetVal.Name -notcontains $_}) -join ','
		          write-host "WARNING (Get-OceanStorLUN): LUN(s) with Name(s) $($NotFoundLUNNames) not found" -foreground "Yellow"
		        }
			  }
			}
			else {
		      if (-not $Silent) {
		        write-host "ERROR (Get-OceanStorLUN): LUN(s) with Name(s) $($Name -join ',') not found" -foreground "Red"
		      }
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
	    write-host "ERROR (Get-OceanStorLUN): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  if ($CanDelete) {
    $RetVal = $RetVal | where {$_.EXPOSEDTOINITIATOR -eq 'false' -and (($_.HASRSSOBJECT | ConvertFrom-JSON).PSObject.properties.Value -notcontains $true)}
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}

