Function New-OceanStorLUN {
  [CmdletBinding(DefaultParameterSetName="LUNName")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='LUNName')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='LUNName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='LUNName')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='LUNName')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='LUNName')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='LUNName')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='LUNName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "Thin - if True then create Thin LUN. Thick LUN creation by default",ParameterSetName='LUNName')][bool]$Thin=$true,
    [PARAMETER(Mandatory=$True, Position=7,HelpMessage = "Storage Pool Name",ParameterSetName='LUNName')][String]$StoragePoolName,
    [PARAMETER(Mandatory=$True, Position=8,HelpMessage = "Size GB",ParameterSetName='LUNName')][int]$Size,
    [PARAMETER(Mandatory=$True, Position=9,HelpMessage = "LUN name",ParameterSetName='LUNName')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
  )
  $RetVal = $null
 
  Fix-OceanStorConnection
  
  # -Name for Get-OceanStorStoragePool is case insensitive
  $StoragePool   = Get-OceanStorStoragePool -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True -Name $StoragePoolName

  if ($Thin) {
    $AllocType = 1 # Thin LUN
  }
  else {
    $AllocType = 0 # Thick LUN
  }  
  
  if ((-not $StoragePool) -or ($StoragePool.Count -gt 1)) {
    if (-not $Silent) {
      write-host "ERROR (New-OceanStorLUN): Wrong storage pool specified (searching by name $($StoragePoolName) got $($StoragePool))" -foreground "Red"
    }
  }
  else {  
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
  	        write-host "WhatIf (New-OceanStorLUN):: Create thin LUN with name $($CurrentName) and size $($Size) GB in Storage pool $($StoragePoolName) (pool ID $($StoragePool.ID)) " -foreground "Green"
		  }
		  else {
  	        write-host "WhatIf (New-OceanStorLUN):: Create thick LUN with name $($CurrentName) and size $($Size) GB in Storage pool $($StoragePoolName) (pool ID $($StoragePool.ID)) " -foreground "Green"
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

