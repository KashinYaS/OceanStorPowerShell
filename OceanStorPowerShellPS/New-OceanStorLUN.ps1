Function New-OceanStorLUN {
  [CmdletBinding(DefaultParameterSetName="LUNName")]
  PARAM (
    [PARAMETER(Mandatory=$true,  Position=0, HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='LUNName')][String]$OceanStor,
    [PARAMETER(Mandatory=$false, Position=1, HelpMessage = "Port",ParameterSetName='LUNName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$true,  Position=2, HelpMessage = "Username",ParameterSetName='LUNName')][String]$Username,
    [PARAMETER(Mandatory=$true,  Position=3, HelpMessage = "Password",ParameterSetName='LUNName')][String]$Password,
    [PARAMETER(Mandatory=$false, Position=4, HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='LUNName')][int]$Scope=0,
    [PARAMETER(Mandatory=$false, Position=5, HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='LUNName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$false, Position=6, HelpMessage = "Thin - if True then create Thin LUN. Thin LUN creation by default",ParameterSetName='LUNName')][bool]$Thin=$true,
    [PARAMETER(Mandatory=$false, Position=7, HelpMessage = "Application Type Name",ParameterSetName='LUNName')][String]$AppTypeName='Default',
    [PARAMETER(Mandatory=$false, Position=8, HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='LUNName')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$false, Position=9, HelpMessage = "Storage Pool Name",ParameterSetName='LUNName')][String]$StoragePoolName = $null,
    [PARAMETER(Mandatory=$true, Position=10, HelpMessage = "Size GB",ParameterSetName='LUNName')][int]$Size,
    [PARAMETER(Mandatory=$true, Position=11, HelpMessage = "LUN name",ParameterSetName='LUNName')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
  )
  $RetVal = $null
 
  Fix-OceanStorConnection
  
  # -Name for Get-OceanStorStoragePool is case insensitive
  if ($StoragePoolName) {
    $StoragePool   = Get-OceanStorStoragePool -OceanStor "$OceanStor" -Port $Port -Username "$Username" -Password "$Password" -Scope $Scope -Silent $true -Name "$StoragePoolName"
  }
  else {
	$StoragePool   = Get-OceanStorStoragePool -OceanStor "$OceanStor" -Port $Port -Username "$Username" -Password "$Password" -Scope $Scope -Silent $true
  }

  if ($Thin) {
    $AllocType = 1 # Thin LUN
  }
  else {
    $AllocType = 0 # Thick LUN
  }  
  
  if ($AppTypeName -eq 'Default') {
	$ApplicationTypeId =0
  }
  else {
    $ApplicationType = Get-OceanStorApplicationType -OceanStor "$OceanStor" -Port $Port -Username "$Username" -Password "$Password" -Scope $Scope -Silent $true -Name "$AppTypeName"
	if ($ApplicationType) {
	  $ApplicationTypeId = $ApplicationType.ID
	}
	else {
	  $ApplicationTypeId = -1	
	}
  }
  
  if ((-not $StoragePool) -or ($StoragePool.Count -gt 1)) {
    if (-not $Silent) {
	  if (-not $StoragePoolName) {
        if ($StoragePool.Count -gt 1) {
		  write-host "ERROR (New-OceanStorLUN): No Storage Pool name specified and more than one Storage Pool exists $($StoragePool.Name -join ', ')" -foreground "Red"
		}
		else {
		  write-host "ERROR (New-OceanStorLUN): No Storage Pool name specified, no Storage Pools found" -foreground "Red"
		}
	  }
	  else {
        if ($StoragePool.Count -gt 1) {
		  write-host "ERROR (New-OceanStorLUN): Found $($StoragePool.Count) Storage Pools ($($StoragePool.Name -join ', ')) with name $($StoragePoolName). How is this possible at all???" -foreground "Red"
		}
		else {
		  write-host "ERROR (New-OceanStorLUN): No Storage Pool $($StoragePoolName) found" -foreground "Red"
		}
	  }		
    }
  }
  elseif ($ApplicationTypeId -eq (-1)) {
    if (-not $Silent) {
      write-host "ERROR (New-OceanStorLUN): Wrong Application Type specified (searching by name $($AppTypeName) failed)" -foreground "Red"
    }	  
  }
  else {
    $StoragePoolName = $StoragePool.NAME    
	
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
  
  	  $URI = $RESTURI  + "lun"
  
      $RetVal = @() 
  
  	  $ProcessedLUN = 0
      foreach ($CurrentName in $Name) {
        if (-not $Silent) {
          $PercentCompletedLUN = [math]::Floor($ProcessedLUN / $Name.Count * 100)
  	      Write-Progress -Activity "Adding LUN " -CurrentOperation "$($CurrentName)" -PercentComplete $PercentCompletedLUN
  	    }
        
  	    $LUNForJSON = @{
          NAME = $CurrentName
		  ALLOCTYPE = $AllocType # 0 - Thick, 1 - Thin
  		  PARENTID = $StoragePool.ID
  	      CAPACITY = 2097152 * $Size
		  MSGRETURNTYPE = 1 # 1 - Syncronous, 0 - Async
		  DATATRANSFERPOLICY = 1 # 0 - no migration, 1 - automatic migration, 2 - migration to a higher performance tier, 3 - migration to a lower performance tier
		  WORKLOADTYPEID = $ApplicationTypeId
        }
  
        if (-not $WhatIf) {	
          $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $LUNForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
  	        $RetVal += $result.data		
          }
          else {
            $RetVal += $null
  	        if (-not $Silent) {
  	          write-host "ERROR (New-OceanStorLUN): $($result.error.code); $($result.error.description)" -foreground "Red"
  	        }
          }
  	    }
  	    else {
		  if ($Thin) {
  	        write-host "WhatIf (New-OceanStorLUN): Create thin LUN with name $($CurrentName) and size $($Size) GB in Storage pool $($StoragePoolName) (pool ID $($StoragePool.ID)) with Application Type $($AppTypeName) (ID $($ApplicationTypeId))" -foreground "Green"
		  }
		  else {
  	        write-host "WhatIf (New-OceanStorLUN): Create thick LUN with name $($CurrentName) and size $($Size) GB in Storage pool $($StoragePoolName) (pool ID $($StoragePool.ID)) with Application Type $($AppTypeName) (ID $($ApplicationTypeId))" -foreground "Green"
		  }		  
  	    }
        $ProcessedLUN += 1    
      } #foreach $CurrentName
      
	  $URI = $RESTURI  + "sessions"
      $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    
    } # if ($logonsession -and ($logonsession.error.code -eq 0)) {
    Return($RetVal)
  } # if ((-not $StoragePool) -or ($StoragePool.Count -gt 1)) {
}

