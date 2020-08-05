Function New-OceanStorHostGroup {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=7,HelpMessage = "Host group(s) names",ParameterSetName='default')][Parameter(ValueFromRemainingArguments=$true)][Object[]]$StorageHostGroups = $null
  )
  $RetVal = $null
  
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

  $body = @{username = "$($Username)";password = "$($Password)";scope = $Scope}

  $BaseRESTURI = "https://" + $OceanStor + ":" + $Port + "/deviceManager/rest/"
  $SessionURI = $BaseRESTURI  + "xxxxx/sessions"


  # --- OceanStor modification section, one big session, cause no pauses in modification procedure intended ---
  $logonsession = Invoke-RestMethod -Method "Post" -Uri $SessionURI -Body (ConvertTo-Json $body) -SessionVariable WebSession

  if ($logonsession -and ($logonsession.error.code -eq 0)) {
    $sessionid = $logonsession.data.deviceid
    $iBaseToken = $logonsession.data.iBaseToken
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $($Username),'''$($Password''')))
    $header = @{Authorization = "Basic $base64AuthInfo";iBaseToken = $iBaseToken}
    $RESTURI = $BaseRESTURI  + $sessionid +"/"

    $UserCredentials = New-Object System.Management.Automation.PsCredential("$($Username)",$(ConvertTo-SecureString -String "$($Password)" -AsPlainText -force))
  
    # --- host group adding
    if (-not $Silent) {
	  Write-Progress  -Activity "Adding host group(s)" -CurrentOperation "Getting existing host groups" -PercentComplete 10
	}
    $URI = $RESTURI  + "hostgroup"
    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      $OceanStorHostGroups = $result.data
    }
    else {
      $OceanStorHostGroups = @()
    }

    #$AssocURI = $RESTURI  + "hostgroup/associate"
  
    $ProcessedHostGroups = 0
    ForEach ($StorageHostGroup in $StorageHostGroups) {
      $GroupName = $StorageHostGroup.Name
      $PercentCompletedHostGroups = [math]::Floor($ProcessedHostGroups / $StorageHostGroups.Count * 90) + 10
      if (-not $Silent) {
	    Write-Progress  -Activity "Adding host group(s)" -CurrentOperation "Processing $($GroupName)" -PercentComplete $PercentCompletedHostGroups 
	  }
      $ActualHostGroup = $OceanStorHostGroups | where {$_.Name.ToUpper() -eq $GroupName.ToUpper()}

      if ($ActualHostGroup) {
        if (-not $Silent) { write-host "Group $($GroupName) already exists" -foreground "Green" }
      }
      else {
        $GroupForJSON = @{
          NAME = $GroupName
        }
		if ($WhatIf) {
		   write-host "WhatIf (New-OceanStorHostGroup): Add host group $($GroupName)" -foreground "Green" 
		}
		else {
          $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $GroupForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
            if (-not $Silent) { write-host "Group $($GroupName) added" -foreground "Green" }
            $ActualHostGroup = $result.data        
          }
          else {
            if (-not $Silent) { write-host "ERROR (New-OceanStorHostGroup): Failed to add Group $($GroupName): $($result.error.description)" -foreground "Red" }
          }
		}
      }
    	  
    $ProcessedHostGroups += 1  
  }
  # --- end host  adding
  
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
}
# --- OceanStor modification section, one big session end ---


  Return($RetVal)

}

