Function Remove-OceanStorLUN {
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
	[PARAMETER(Mandatory=$False,Position=7,HelpMessage = "Force delete. Specify to delete ALL LUNs",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNName')][switch]$Force,
	[PARAMETER(Mandatory=$False,Position=8,HelpMessage = "Do not remove Replication Pair, only print message",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='LUNName')][switch]$WhatIf
	)
  
  $RetVal = @()
 
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


    if ( ($PSCmdlet.ParameterSetName -eq 'default') -and (-not $Force)) {
      write-host "ERROR (Remove-OceanStorLUN) - No Replication pair specified. Use -Force parameter to delete ALL Replication pairs" -foreground "Red"
    }
    else {
      switch ( $PSCmdlet.ParameterSetName )
      {
        'ID'    {
          $LUNs = Get-OceanStorLUN -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $true -ID $ID 
	    }
        'LUNName'    {
          $LUNs = Get-OceanStorLUN -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $true -Name $Name
	    }
	    default { 
	     $LUNs = Get-OceanStorLUN -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $true
	    }
      }
	  
	}
	
      if (-not $LUNs) {
        write-host "ERROR (Remove-OceanStorLUN) - No LUN(s) found using parameters specified" -foreground "Red"
	  }
      else {
	    if (-not $Silent) {
	      if ($LUNs.Count -gt 1) {
			switch ( $PSCmdlet.ParameterSetName )
            {
               'ID'    {
				 if ($LUNs.Count -lt $ID.Count) {
				   $NotFoundLUNIDs = ($ID | where {$LUNs.ID -notcontains $_}) 
				   write-host "WARNING (Remove-OceanStorLUN) - Found $($LUNs.Count) of $($ID.Count) LUNs to delete. $($NotFoundLUNIDs.Count) LUN(s) with ID(s) $($NotFoundLUNIDs -join ',') not found." -foreground "Yellow"
				 }
				 else {
				   write-host "INFO (Remove-OceanStorLUN) - Found $($LUNs.Count) LUNs to delete" -foreground "Green"
				 }
 	           }
               'LUNName'    {
				 if ($LUNs.Count -lt $Name.Count) {
				   $NotFoundLUNNames = ($Name | where {$LUNs.Name -notcontains $_}) 
				   write-host "WARNING (Remove-OceanStorLUN) - Found $($LUNs.Count) of $($Name.Count) LUNs to delete. $($NotFoundLUNNames.Count) LUN(s) with Name(s) $($NotFoundLUNNames -join ',') not found." -foreground "Yellow"
				 }
				 else {
				   write-host "INFO (Remove-OceanStorLUN) - Found $($LUNs.Count) LUNs to delete" -foreground "Green"
				 }
				   
               }
			   default {
				 write-host "INFO (Remove-OceanStorLUN) - Found $($LUNs.Count) LUNs to delete" -foreground "Green"
			   }
			}			   
		  }
		  else {
		    write-host "INFO (Remove-OceanStorLUN) - Found LUN $($LUNs.ID)/$($LUNs.NAME) to delete" -foreground "Green"
		  }
		}
		foreach ($LUN in $LUNs) {
		  if ($LUN.EXPOSEDTOINITIATOR -eq 'true') {
		    if ($WhatIf) {
			  write-host "WhatIf ERROR (Remove-OceanStorLUN) - LUN $($LUN.ID)/$($LUN.NAME) can not be deleted - it is currently exposed/mapped to host(s)" -foreground "Yellow"
		    }
            else {
			  write-host "ERROR (Remove-OceanStorLUN) - LUN $($LUN.ID)/$($LUN.NAME) can not be deleted - it is currently exposed to host(s)" -foreground "Red"
			}				
		  }
		  else {
			# LUN is unmapped, but still can be a member of replication/metro and so on
			$StopFeatures = ($LUN.HASRSSOBJECT | ConvertFrom-JSON).PSObject.properties | where {$_.Value -eq $True}
			if ($StopFeatures) {
			  $StopFeatureString = ($StopFeatures |  Select Name).Name -join ','
		      if ($WhatIf) {
			    write-host "WhatIf ERROR (Remove-OceanStorLUN) - LUN $($LUN.ID)/$($LUN.NAME) can not be deleted - it is currently used in $($StopFeatureString)" -foreground "Yellow"
		      }
              else {
			    write-host "ERROR (Remove-OceanStorLUN) - LUN $($LUN.ID)/$($LUN.NAME) can not be deleted - it is currently used in $($StopFeatureString)" -foreground "Red"
			  }								
			}
			else {
			  # LUN is unmapped and not used in any known services preventing its deletition
		      if ($WhatIf) {
			    write-host "WhatIf (Remove-OceanStorLUN): Removing LUN ID $($LUN.ID)/$($LUN.NAME)" -foreground "Yellow"
		      }
		      else {
		        # Destructive actions
			    $URI = $RESTURI  + "lun/" + $($LUN.ID)
			
			    $result = Invoke-RestMethod -Method "Delete" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession

                if ($result) {
              	  $result.data | Add-Member -NotePropertyName 'LunID' -NotePropertyValue "$($LUN.ID)"
			    }
			 
                if ($result -and ($result.error.code -eq 0)) {
	              [array]$RetVal += $result
				  if (-not $Silent) {
				    write-host "INFO (Remove-OceanStorLUN) - LUN $($LUN.ID)/$($LUN.NAME) Deleted" -foreground "Green" 
				  }
                }
                else {
		          [array]$RetVal += $result
	              if (-not $Silent) {
	                write-host "ERROR (Remove-OceanStorLUN): Cannot delete LUN $($LUN.ID)/$($LUN.NAME): $($result.error.code); $($result.error.description)" -foreground "Red"
	              }
                }		
				
		      }			  
			}
		  }
		} #foreach ($LUN in $LUNs)
	  } # if (-not $LUNs) else 
	  
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}

