Function Get-OceanStorEnclosure {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][bool]$Silent=$true,
	[PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Enclosure ID",ParameterSetName='ID')][int[]]$ID = $null
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
	      $URI = $RESTURI  + "enclosure/" + $ID
	    }
	    else {
          $URI = $RESTURI  + "enclosure"
	    }
	  }
	  default { 
	    $URI = $RESTURI  + "enclosure" 
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
		           write-host "WARNING (Get-OceanStorEnclosure): Enclosure(s) with ID(s) $($NotFoundEncIDs) not found" -foreground "Yellow"
		         }
			   }
			 }
			 else {
		       if (-not $Silent) {
		         write-host "ERROR (Get-OceanStorEnclosure): Enclosure(s) with ID(s) $($ID -join ',') not found" -foreground "Red"
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
	    write-host "ERROR (Get-OceanStorEnclosure): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  $RawRetVal = $RetVal
  $RetVal=@()
  foreach ($CurrentVal in $RawRetVal) {
	switch ($CurrentVal.Model) {
      '1'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 12-slot 3.5-inch SAS controller enclosure' }
      '2'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 24-slot 2.5-inch SAS controller enclosure' }
      '16'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U SAS 12-disk expansion enclosure' }
      '17'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U SAS 24-disk expansion enclosure' }
      '18'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4U SAS 24-disk expansion enclosure' }
      '19'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4U Fibre Channel 24-disk expansion enclosure' }
      '20'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '1U PCIe data switch' }
      '21'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4U SAS 75-disk expansion enclosure' }
      '22'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue 'service processor (SVP)' }
      '23'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 12 GB 12-slot 3.5-inch SAS controller enclosure' }
      '24'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U SAS 25-disk (2.5-inch) enclosure' }
      '25'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4U SAS 24-disk (3.5-inch) enclosure (new)' }
      '26'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 12 GB 25-slot 2.5-inch SAS controller enclosure' }
      '39'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4U 12 GB 75-slot 3.5-inch SAS disk enclosure' }
      '65'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 12G 25 Slot 2.5 SSD Disks Enclosure	' }	
      '67'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 25-slot 2.5-inch SAS disk enclosure' }
      '69'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4U 24-slot 3.5-inch SAS disk enclosure' }
      '96'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '3U 2-controller independent engine' }
      '97'  { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '6U 4-controller independent engine' }
      '112' { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4U 4-controller controller enclosure' }
      '113' { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 2-controller 25-slot 2.5-inch SAS controller enclosure' }
      '114' { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 2-controller 12-slot 3.5-inch SAS controller enclosure' }
      '115' { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 2-controller 36-slot NVMe controller enclosure' }
      '116' { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 2-controller 25-slot 2.5-inch SAS controller enclosure' }
      '117' { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 2-controller 12-slot 3.5-inch SAS controller enclosure' }
      '118' { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 25-slot 2.5-inch smart SAS disk enclosure' }
      '119' { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 12-slot 3.5-inch smart SAS disk enclosure' }
      '120' { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 36-slot smart NVMe disk enclosure' }
      '122' { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2U 2-controller 25-slot 2.5-inch NVMe controller enclosure ' } 
    }
	[array]$RetVal += $CurrentVal
  }
   
  Return($RetVal)
}

