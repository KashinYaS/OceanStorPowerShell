Function New-OceanStorFCInitiator {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Initiator's Port WWN",ParameterSetName='default')][Parameter(ValueFromRemainingArguments=$true)][String[]]$pWWN = $null
  )
  $RetVal = @()
 
  # --- prepare to connect with TLS 1.2 and ignore self-signed certificate of OceanStor ---
  [Net.ServicePointManager]::SecurityProtocol =[Net.SecurityProtocolType]::Tls12

  Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@ -ea SilentlyContinue -wa SilentlyContinue    
  [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
  # --- end TLS and Cert preparation ---
  # Caution! Any self-signed and invalid certificate are truated furthermore!

  # --- Section 1 --- getting existing FC initiators
  if (-not $Silent) {
    Write-Progress  -Activity " Getting FC initiatiors from OceanStor $($OceanStor)" -CurrentOperation "Getting..." -PercentComplete 5 -Id 1
  }
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

    $URI = $RESTURI  + "fc_initiator"
    $result = Invoke-RestMethod -Method Get $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      $OceanStorFCInitiators = $result.data | where {$_.TYPE -eq "223"}
    }
    else {
      $OceanStorFCInitiators = $null
    }
  
    $URI = $RESTURI  + "sessions"
    $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  }
  
  # --- Section 2 --- Comparing existing FC initiators with $pWWN parameter
  if (-not $Silent) {
    Write-Progress  -Activity "Checking what FC initiators to add" -CurrentOperation "Getting..." -PercentComplete 10 -Id 1
  }
  $NewFCInitiators = @()
  foreach ($CurrentpWWN in $pWWN) {
    $OceanStorFCFound = $OceanStorFCInitiators | where {$_.ID.ToUpper() -eq $CurrentpWWN.ToUpper()}
	if (-not $OceanStorFCFound) {
	  $NewFCInitiators += $CurrentpWWN.ToUpper()
	}
  }
  
  # --- Section 3 --- Adding new FC initiators
  if (-not $Silent) {
    Write-Progress  -Activity "Processing OceanStor's FC initiatores" -CurrentOperation "Getting..." -PercentComplete 40 -Id 1
  }
  
  if ($NewFCInitiators.Count -gt 0) {
    $logonsession = Invoke-RestMethod -Method "Post" -Uri $SessionURI -Body (ConvertTo-Json $body) -SessionVariable WebSession

    if ($logonsession -and ($logonsession.error.code -eq 0)) {
      $sessionid = $logonsession.data.deviceid
      $iBaseToken = $logonsession.data.iBaseToken
      $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $($Username),'''$($Password''')))
      $header = @{Authorization = "Basic $base64AuthInfo";iBaseToken = $iBaseToken}
      $RESTURI = $BaseRESTURI  + $sessionid +"/"

      $UserCredentials = New-Object System.Management.Automation.PsCredential("$($Username)",$(ConvertTo-SecureString -String "$($Password)" -AsPlainText -force))

      $URI = $RESTURI  + "fc_initiator"
	  
      $ProcessedFCInitiators = 0
      foreach ($FCInitiator in $NewFCInitiators) {
        $PercentCompletedFCInitiators = [math]::Floor($ProcessedFCInitiators / $NewFCInitiators.Count * 100)
        if (-not $Silent) {
		  Write-Progress  -Activity "Processing OceanStor's FC Initiators" -CurrentOperation "$FCInitiator" -PercentComplete $PercentCompletedFCInitiators -Id 2 -ParentId 1
		}
        $FCInitiatorForJSON = @{
          ID = $FCInitiator
        }
        if ($WhatIf) {
		  write-host "New-OceanStorFCInitiator: Adding FC initiator $($FCInitiator)" -foreground "Green"
        }
        else {		
          $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $FCInitiatorForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
            $RetVal += $result.data
            if (-not $Silent) {
		      write-host "New-OceanStorFCInitiator: FC initiator $($FCInitiator.pWWN) added" -foreground "Green"
		    }
          }
          else {
            if (-not $Silent) {
		      write-host "New-OceanStorFCInitiator: Failed to add FC initiator $($FCInitiator.pWWN): $($result.error.description)" -foreground "Red"
		    }
          }
        }		  
        $ProcessedFCInitiators += 1
      }
    $URI = $RESTURI  + "sessions"
    $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    }
  }
  else {
    if (-not $Silent) {
      write-host "Nothing to add. All specified FC initiators already exist on $($OceanStor)" -foreground "Green"
	}
  }
  # --- end adding FC initiators on OceanStor ---
 
 Return($RetVal)   
}


