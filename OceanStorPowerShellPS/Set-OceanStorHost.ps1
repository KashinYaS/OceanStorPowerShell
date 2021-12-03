Function Set-OceanStorHost {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=7,HelpMessage = "Host(s) (object with host parameters, ID is mandatory (get example with Get-OceanStorHost))",ParameterSetName='default')][Parameter(ValueFromRemainingArguments=$true)][Object[]]$StorageHosts = $null
  )
  $RetVal = $null
  
  Fix-OceanStorConnection

  $body = @{username = "$($Username)";password = "$($Password)";scope = $Scope}

  $BaseRESTURI = "https://" + $OceanStor + ":" + $Port + "/deviceManager/rest/"
  $SessionURI = $BaseRESTURI  + "xxxxx/sessions"

  $OceanStorHosts = Get-OceanStorHost -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $true

  #$OceanStorHostsForModification = $OceanStorHosts | where {$StorageHosts.ID.Contains($_.ID)}
  
  $AllowedProperties = @('DESCRIPTION','HEALTHSTATUS','ID','IP','LOCATION','MODEL','NAME','NETWORKNAME','OPERATIONSYSTEM','TYPE')
  
  $RefinedStorageHosts =@()
  
  foreach ($StorageHost in $StorageHosts) {
	$NormalizedStorageHost = New-Object PSObject
	$Properties = $StorageHost.PSObject.Properties
	foreach ($Property in $Properties) {
	   if ($AllowedProperties.Contains($Property.Name.ToUpper())) {
	     $NormalizedStorageHost | Add-Member -NotePropertyName $Property.Name -NotePropertyValue $StorageHost.$($Property.Name)
	   }
	   else {
		 if (-not $Silent) {
		   write-host "WARNING (Set-OceanStorHost): Host property $($Property.Name) in not allowed to set - skipping property" -foreground "Yellow"
		 }
	   }
	}
	
    $ExistingHost = $OceanStorHosts | where {$_.ID -eq $NormalizedStorageHost.ID}
	if (-not $ExistingHost) {
	  if (-not $Silent) {
	    write-host "ERROR (Set-OceanStorHost): Host with ID $($StorageHost.ID) not found - skipping modification" -foreground "Red"
	  }
	}
	else {
	  #$ExistingHostProperties = Get-Member -InputObject $ExistingHost  -MemberType Property
	  #$NormalizedStorageHostProperties = Get-Member -InputObject $NormalizedStorageHost  -MemberType Property
	  $ExistingHostProperties = $ExistingHost.PSObject.Properties
	  $NormalizedStorageHostProperties = $NormalizedStorageHost.PSObject.Properties
	  
	  $RefinedStorageHost = New-Object PSObject
	  $ChangedProperties = 0
	  foreach ($Property in $NormalizedStorageHostProperties) {
		$SrcProperty = $ExistingHostProperties | where {$_.Name -eq $Property.Name}
		if ($SrcProperty) {
		  if (-not ($Property.Value -ceq $SrcProperty.Value)) {
			$RefinedStorageHost | Add-Member -NotePropertyName $($Property.Name) -NotePropertyValue $NormalizedStorageHost.$($Property.Name)
		    $ChangedProperties += 1			
			if (-not $Silent) {
			  write-host "INFO (Set-OceanStorHost): Preparing to replace Host's $($ExistingHost.NAME)/$($ExistingHost.ID) property $($Property.Name) with ""$($Property.Value)"" (old value ""$($SrcProperty.Value)"")" -foreground "Green"
			}
		  }
		  else {
			if ((-not $Silent) -and (-not ($Property.Name.ToUpper() -eq 'ID'))) {
			  write-host "INFO (Set-OceanStorHost): Skipping Host's $($ExistingHost.NAME)/$($ExistingHost.ID) property $($Property.Name) modification - same values specified ($($Property.Value),$($SrcProperty.Value))" -foreground "Green"
			}
			if ($Property.Name.ToUpper() -eq 'ID') {
			  $RefinedStorageHost | Add-Member -NotePropertyName 'ID' -NotePropertyValue $NormalizedStorageHost.$($Property.Name)
			}
		  }
		}
		else {
     	  if (-not $Silent) {
	        write-host "ERROR (Set-OceanStorHost): No property $($Property.Name) found. This error should not fire normally due to property name normalization." -foreground "Red"
	      }
		}
	  }

      if ($ChangedProperties -eq 0) {
     	if (-not $Silent) {
	      write-host "INFO (Set-OceanStorHost): Skipping Host's $($ExistingHost.NAME)/$($ExistingHost.ID) reconfiguration - all properties are the same as in OceanStor" -foreground "Yellow"
	    }
	  }
	  else {
		$RefinedStorageHosts += $RefinedStorageHost
	  }
	}
  }
  
  if ($RefinedStorageHosts) {
    $logonsession = Invoke-RestMethod -Method "Post" -Uri $SessionURI -Body (ConvertTo-Json $body) -SessionVariable WebSession

    if ($logonsession -and ($logonsession.error.code -eq 0)) {
      $sessionid = $logonsession.data.deviceid
      $iBaseToken = $logonsession.data.iBaseToken
      $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $($Username),'''$($Password''')))
      $header = @{Authorization = "Basic $base64AuthInfo";iBaseToken = $iBaseToken}
      $RESTURI = $BaseRESTURI  + $sessionid +"/"

      $UserCredentials = New-Object System.Management.Automation.PsCredential("$($Username)",$(ConvertTo-SecureString -String "$($Password)" -AsPlainText -force))

      foreach ($HostForJSON in $RefinedStorageHosts) {
	    $HostName = ($OceanStorHosts | where {$_.ID -eq $HostForJSON.ID}).Name
        if ($WhatIf) {
		  write-host "WhatIf (Set-OceanStorHost): Setting Host $($Hostname)/$($HostForJSON.ID) parameters" -foreground "Yellow" 
	    }
	   else {
		   
		  $URI = $RESTURI  + "host/" + $($HostForJSON.ID)
		  
          $result = Invoke-RestMethod -Method "PUT" -Uri $URI -Body (ConvertTo-Json $HostForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
            if (-not $Silent) { write-host "INFO (Set-OceanStorHost): Succesfully Modified Host $($Hostname)/$($HostForJSON.ID)" -foreground "Green" }
             $RetVal += $result.data        
            }
            else {
              if (-not $Silent) { write-host "ERROR (New-OceanStorHost): Failed to Modify Host $($Hostname)/$($HostForJSON.ID): $($result.error.description)" -foreground "Red" }
            }
	    }

	  }
	
      $URI = $RESTURI  + "sessions"
      $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession  
    }
  }
  
  Return($RetVal)

}

