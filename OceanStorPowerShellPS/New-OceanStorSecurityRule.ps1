Function New-OceanStorSecurityRule {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=7,HelpMessage = "IP - IP address or IP  addresses",ParameterSetName='default')][Parameter(ValueFromRemainingArguments=$true)][string[]]$IP = $null
  )
  $RetVal = @()
  
  # This function only Adds Security Rule(s). But not Enables/Disables them!
  
  Fix-OceanStorConnection

  $body = @{username = "$($Username)";password = "$($Password)";scope = $Scope}

  $BaseRESTURI = "https://" + $OceanStor + ":" + $Port + "/deviceManager/rest/"
  $SessionURI = $BaseRESTURI  + "xxxxx/sessions"

  $logonsession = Invoke-RestMethod -Method "Post" -Uri $SessionURI -Body (ConvertTo-Json $body) -SessionVariable WebSession

  if ($logonsession -and ($logonsession.error.code -eq 0)) {
    $sessionid = $logonsession.data.deviceid
    $iBaseToken = $logonsession.data.iBaseToken
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $($Username),'''$($Password''')))
    $header = @{Authorization = "Basic $base64AuthInfo";iBaseToken = $iBaseToken}
    $RESTURI = $BaseRESTURI  + $sessionid +"/"

    $UserCredentials = New-Object System.Management.Automation.PsCredential("$($Username)",$(ConvertTo-SecureString -String "$($Password)" -AsPlainText -force))

    $OceanStorSecurityRules = Get-OceanStorSecurityRule -OceanStor "$OceanStor" -Port $Port -Username "$Username" -Password "$Password" -Scope $Scope -Silent $true

    $URI = $RESTURI  + "iprule"
	
    $ProcessedSecurityRules = 0
    ForEach ($CurrentIP in $IP) {
      $PercentCompletedSecurityRules = [math]::Floor($ProcessedSecurityRules / $IP.Count * 100)
      if (-not $Silent) {
	    Write-Progress  -Activity "Adding SecurityRule" -CurrentOperation "IP: $($CurrentIP)" -PercentComplete $PercentCompletedSecurityRules 
	  }
      $ActualSecurityRule = $OceanStorSecurityRules | where {$_.SECUREIP -eq $CurrentIP}

      if ($ActualSecurityRule) {
        if (-not $Silent) { write-host "Security Rule with IP $($CurrentIP) already exists" -foreground "Green" }
      }
      else {
        $SecurityRuleForJSON = @{
          SECUREIP = $CurrentIP
          STRATEGY = "1"
        }
		if ($WhatIf) {
		   write-host "WhatIf (New-OceanStorSecurityRule): Add Security Rule with IP $($CurrentIP)" -foreground "Green" 
		}
		else {
          $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $SecurityRuleForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
            if (-not $Silent) { write-host "Security Rule with IP $($CurrentIP) added" -foreground "Green" }
            $RetVal += $result.data
          }
          else {
            if (-not $Silent) { write-host "ERROR (New-OceanStorSecurityRule): Failed to add Security Rule with IP $($CurrentIP): $($result.error.description)" -foreground "Red" }
          }
		}
      }    
	}
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession

  }
  
  Return($RetVal)
}

