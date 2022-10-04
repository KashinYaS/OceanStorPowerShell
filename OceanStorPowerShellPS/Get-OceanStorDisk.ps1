Function Get-OceanStorDisk {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Location')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Location')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Location')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Location')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Location')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Location')][bool]$Silent=$true,
	[PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Disk ID",ParameterSetName='ID')][int[]]$ID = $null,
	[PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Disk Location",ParameterSetName='Location')][String[]]$Location = $null
	
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
	      $URI = $RESTURI  + "disk/" + $ID
	    }
	    else {
          $URI = $RESTURI  + "disk"
	    }
	  }
	  'Location' { 
	    $URI = $RESTURI  + "disk" 
	  }
	  default { 
	    $URI = $RESTURI  + "disk" 
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
				   $NotFoundEncIDs = ($ID | where {$RetVal.ID -notcontains $_}) -join ','
		           write-host "WARNING (Get-OceanStorDisk): Disk(s) with ID(s) $($NotFoundEncIDs) not found" -foreground "Yellow"
		         }
			   }
			 }
			 else {
		       if (-not $Silent) {
		         write-host "ERROR (Get-OceanStorDisk): Disk(s) with ID(s) $($ID -join ',') not found" -foreground "Red"
		       }
             }
	       }		  
		}		  
        'Location' {
	       if ( $Location.Count -eq 1 ) { 
	         $RetVal = $result.data	| where { $Location -eq $_.Location }	
	       }
	       else { # several objects specified - need to select some of them
	         $RetVal = $result.data | where { $Location -contains $_.Location }		     
			 if ($RetVal) {
			   if ($RetVal.Count -lt $Location.Count) {
			     if (-not $Silent) {
				   $NotFoundEncLocations = ($Location | where {$RetVal.Location -notcontains $_}) -join ','
		           write-host "WARNING (Get-OceanStorDisk): Disk(s) with Location(s) $($NotFoundEncLocations) not found" -foreground "Yellow"
		         }
			   }
			 }
			 else {
		       if (-not $Silent) {
		         write-host "ERROR (Get-OceanStorDisk): Disk(s) with Location(s) $($Location -join ',') not found" -foreground "Red"
		       }
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
	    write-host "ERROR (Get-OceanStorDisk): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  $RawRetVal = $RetVal
  $RetVal=@()
  foreach ($CurrentVal in $RawRetVal) {
	switch ($CurrentVal.DISKIFTYPE) {
      '0'      { $CurrentVal | Add-Member -NotePropertyName 'DiskIfTypeNameEx' -NotePropertyValue 'Not Available' }
      '1'      { $CurrentVal | Add-Member -NotePropertyName 'DiskIfTypeNameEx' -NotePropertyValue 'FC SSD' }
      '2'      { $CurrentVal | Add-Member -NotePropertyName 'DiskIfTypeNameEx' -NotePropertyValue 'SAS SSD' }
      '3'      { $CurrentVal | Add-Member -NotePropertyName 'DiskIfTypeNameEx' -NotePropertyValue 'NL-SAS SSD' }
      '4'      { $CurrentVal | Add-Member -NotePropertyName 'DiskIfTypeNameEx' -NotePropertyValue 'SATA SSD' }
      '5'      { $CurrentVal | Add-Member -NotePropertyName 'DiskIfTypeNameEx' -NotePropertyValue 'SATA2 SSD' }
      '6'      { $CurrentVal | Add-Member -NotePropertyName 'DiskIfTypeNameEx' -NotePropertyValue 'SATA3 SSD' }	  
    }
	switch ($CurrentVal.DISKTYPE) {
      '0'      { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'FC' }
      '1'      { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'SAS' }
      '2'      { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'SATA' }
      '3'      { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'SSD' }
      '4'      { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'NL-SAS' }
      '5'      { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'SLC SSD' }
      '6'      { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'MLC SSD' }
      '7'      { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'FC SED' }
      '8'      { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'SAS SED' }
      '9'      { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'SATA SED' }
      '10'     { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'SSD SED' }
      '11'     { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'NL-SAS SED' }
      '12'     { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'SLC SSD SED' }
      '13'     { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'MLC SSD SED' }
      '14'     { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'NVMe SSD' }
      '16'     { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'NVMe SSD SED' }
      '17'     { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'SCM' }
      '18'     { $CurrentVal | Add-Member -NotePropertyName 'DiskTypeNameEx' -NotePropertyValue 'SCM SED' }
	}
	switch ($CurrentVal.DISKFORM) {
      '0'      { $CurrentVal | Add-Member -NotePropertyName 'DiskFormNameEx' -NotePropertyValue 'unknown' }
      '1'      { $CurrentVal | Add-Member -NotePropertyName 'DiskFormNameEx' -NotePropertyValue '5.25-inch' }
      '2'      { $CurrentVal | Add-Member -NotePropertyName 'DiskFormNameEx' -NotePropertyValue '3.5-inch' }
      '3'      { $CurrentVal | Add-Member -NotePropertyName 'DiskFormNameEx' -NotePropertyValue '2.5-inch' }
      '4'      { $CurrentVal | Add-Member -NotePropertyName 'DiskFormNameEx' -NotePropertyValue '1.8-inch' }
	}		
	[array]$RetVal += $CurrentVal
  }
   
  Return($RetVal)
}

