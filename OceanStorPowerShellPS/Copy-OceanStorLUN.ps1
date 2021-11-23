Function Copy-OceanStorLUN {
  [CmdletBinding(DefaultParameterSetName="LUNName")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "Source OceanStor's FQDN or IP address",ParameterSetName='LUNName')][String]$SourceOceanStor,
    [PARAMETER(Mandatory=$True, Position=1,HelpMessage = "Destination OceanStor's FQDN or IP address",ParameterSetName='LUNName')][String]$DestinationOceanStor,	
    [PARAMETER(Mandatory=$False,Position=2,HelpMessage = "Port",ParameterSetName='LUNName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Username",ParameterSetName='LUNName')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=4,HelpMessage = "Password",ParameterSetName='LUNName')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='LUNName')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='LUNName')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=7,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='LUNName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WithAppType - Copy Application Type too if it does not exist on a destination OceanStor",ParameterSetName='LUNName')][switch]$WithAppType,	
    [PARAMETER(Mandatory=$True, Position=9,HelpMessage = "LUN name",ParameterSetName='LUNName')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
  )
  $RetVal = $null
   
  Fix-OceanStorConnection
  
  $SourceLUNs = Get-OceanStorLUN -OceanStor $SourceOceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True | where {$Name.Contains($_.NAME)}
  
  if (-not $SourceLUNs) {
    if (-not $Silent) {
	  write-host "ERROR (Copy-OceanStorLUN): No LUNs found for specified Name on a Source OceanStor" -foreground "Red"
	}
  }
  else {
	if ( ($Name.Count -gt 1) -and ($Name.Count -ne $SourceLUNs.Count)) {
	  if (-not $Silent) {
	    $NotFoundLUNNames = $Name | where {-not $SourceLUNs.NAME.Contains($_)}
	    foreach ($NotFoundLUNName in $NotFoundLUNNames) {
		  write-host "ERROR (Copy-OceanStorLUN): LUN $($NotFoundLUNName) not found on a Source OceanStor" -foreground "Red"
		}
	  }
	}
	else {
	  # All LUNs found
	  # no need to search Source Application Type / Workload type cause it already exists in LUN data
	  # $SourceAppTypes = Get-OceanStorApplicationType -OceanStor $SourceOceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True
	  $DestinationAppTypes = Get-OceanStorApplicationType -OceanStor $DestinationOceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True
	  $NotFoundAppTypes = $SourceLUNs.WORKLOADTYPENAME | where {-not $DestinationAppTypes.NAME.Contains($_)}
	  if ($NotFoundAppTypes) {
        foreach ($NotFoundAppType in $NotFoundAppTypes) {
	      if (-not $Silent) {
			if (-not $WithAppType) {  
			  write-host "ERROR (Copy-OceanStorLUN): No Application Type $($NotFoundAppType) found on a Destination OceanStor. Use -WithAppType parameter to copy Application Types too." -foreground "Red"			
			}
			else {
			  write-host "INFO (Copy-OceanStorLUN): No Application Type $($NotFoundAppType) found on a Destination OceanStor" -foreground "Green"			
			}
		  }
		}
        if ($WithAppType) {
		  $SourceAppTypes = Get-OceanStorApplicationType -OceanStor $SourceOceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True
		  $SourceAppTypes = $SourceAppTypes | where {$NotFoundAppTypes.Contains($_.NAME)}
          $SourceAppTypes | ft -a		  
		  foreach ($SourceAppType in $SourceAppTypes) {
			if ($SourceAppType.ENABLECOMPRESS) { $Compression = $True } else {$Compression = $False}
			if ($SourceAppType.ENABLEDEDUP) { $Deduplication = $True } else {$Deduplication = $False}
			if (-not $WhatIf) {
			  if (-not $Silent){
			    write-host "INFO (Copy-OceanStorLUN): Adding Application type $($SourceAppType.NAME) on a Destination OceanStor" -foreground "Green"
			  }
			  if (($SourceAppType.ENABLECOMPRESS -eq 'true') -and ($SourceAppType.ENABLEDEDUP -eq 'true')) {
			    $DestinationAppTypes += New-OceanStorApplicationType -OceanStor $DestinationOceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True -Compression -Deduplication -RequestSize $SourceAppType.BLOCKSIZE -Name $SourceAppType.NAME		
 			  }
			  elseif (($SourceAppType.ENABLECOMPRESS -eq 'true') -and ($SourceAppType.ENABLEDEDUP -eq 'false')) {
			    $DestinationAppTypes += New-OceanStorApplicationType -OceanStor $DestinationOceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True -Compression -RequestSize $SourceAppType.BLOCKSIZE -Name $SourceAppType.NAME		
			  }
			  elseif (($SourceAppType.ENABLECOMPRESS -eq 'false') -and ($SourceAppType.ENABLEDEDUP -eq 'true')) {
				$DestinationAppTypes += New-OceanStorApplicationType -OceanStor $DestinationOceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True -Deduplication -RequestSize $SourceAppType.BLOCKSIZE -Name $SourceAppType.NAME		
			  }
			  else {
				$DestinationAppTypes += New-OceanStorApplicationType -OceanStor $DestinationOceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True -RequestSize $SourceAppType.BLOCKSIZE -Name $SourceAppType.NAME		
			  }
			}	
			else {
			  write-host "WhatIf (Copy-OceanStorLUN): Creating Application Type $($SourceAppType.NAME) on a Destination OceanStor" -foreground "Yellow"
			}
		  }
		}
	  } # if ($NotFoundAppTypes)
      $NotFoundAppTypes = $SourceLUNs.WORKLOADTYPENAME | where {-not $DestinationAppTypes.NAME.Contains($_)}
	   if ($NotFoundAppTypes) {
	     if (-not $Silent) {
		   write-host "ERROR (Copy-OceanStorLUN): Application types are not consistent. Skipping LUN copy." -foreground "Red"
		 }
	   }
	   else {
		 # LUN types are consistent, so let's try to add new LUNs
		 $RetVal = @()
		 foreach ($SourceLUN in $SourceLUNs) {
		   if ($WhatIf) {
		     write-host "WhatIf (Copy-OceanStorLUN): Creating LUN $($SourceLUN.NAME) on a Destination OceanStor" -foreground "Yellow"
		   }
		   else {
			 $LUNSizeGB = [math]::round( $SourceLUN.CAPACITY / 1048576, 0)
             if ($SourceLUN.ALLOCTYPE -eq 1) { $ThinLun = $true } else {$ThinLun = $false }
		     $LUN = New-OceanStorLUN -OceanStor $DestinationOceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True -Name $($SourceLUN.NAME) -StoragePoolName $($SourceLUN.PARENTNAME) -Size $LUNSizeGB -Thin $ThinLun -AppTypeName $($SourceLUN.WORKLOADTYPENAME)
			 if ($LUN) {
			   $RetVal += $LUN
	           if (-not $Silent) {
			     write-host "INFO (Copy-OceanStorLUN): LUN $($SourceLUN.NAME) added on a Destination OceanStor" -foreground "Green"
			   }
			 }
		   }
		 } #foreach ($SourceLUN in $SourceLUNs)
	   }
	}	
  }
  
  Return($RetVal)
}

