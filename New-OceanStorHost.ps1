Function New-OceanStorHost {
  [CmdletBinding(DefaultParameterSetName="default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='default')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='default')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='default')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=7,HelpMessage = "Host(s) (object with Name, FirstpWWN and SecondpWWN parameters)",ParameterSetName='default')][Parameter(ValueFromRemainingArguments=$true)][Object[]]$StorageHosts = $null
  )
  $RetVal = $null
  
  $PARENTTYPE = 21
  $MULTIPATHTYPE = 1
  $FAILOVERMODE = 3
  $SPECIALMODETYPE = 2
  # "multipath_type=third-party failover_mode=special_mode special_mode_type=mode2"    		  
 
  $OPERATIONSYSTEM = 7 #VMware ESXi

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
  
    # --- host adding
    if (-not $Silent) {
	  Write-Progress  -Activity "Adding ESXi hosts as a Hosts" -CurrentOperation "Getting existing hosts" -PercentComplete 10
	}
    $URI = $RESTURI  + "host"
    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      $OceanStorHosts = $result.data
    }
    else {
      $OceanStorHosts = @()
    }

    #$AssocURI = $RESTURI  + "hostgroup/associate"
  
    $ProcessedHosts = 0
    ForEach ($StorageHost in $StorageHosts) {
      $HostName = $StorageHost.Name
      $PercentCompletedHosts = [math]::Floor($ProcessedHosts / $StorageHosts.Count * 90) + 10
      if (-not $Silent) {
	    Write-Progress  -Activity "Adding ESXi hosts as a Hosts" -CurrentOperation "Processing $($HostName)" -PercentComplete $PercentCompletedHosts 
	  }
      $ActualHost = $OceanStorHosts | where {$_.Name.ToUpper() -eq $HostName.ToUpper()}

      if ($ActualHost) {
        if (-not $Silent) { write-host "Host $($ActualHost.Name) already exists" -foreground "Green" }
        $HostsForGrouping += $ActualHost
      }
      else {
        $HostForJSON = @{
          NAME = $HostName
          OPERATIONSYSTEM = $OPERATIONSYSTEM
        }
		if ($WhatIf) {
		   write-host "WhatIf (New-OceanStorHost): Add host $($ActualHost.Name)" -foreground "Green" 
		}
		else {
          $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $HostForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
          if ($result -and ($result.error.code -eq 0)) {
            if (-not $Silent) { write-host "Host $($ActualHost.Name) added" -foreground "Green" }
            $ActualHost = $result.data        
          }
          else {
            if (-not $Silent) { write-host "ERROR (New-OceanStorHost): Failed to add Host $($HostName): $($result.error.description)" -foreground "Red" }
          }
		}
      }
    
	  if ($ActualHost) {
		$PWWN = $StorageHost.FirstpWWN
        if ($PWWN) {
          $InitiatorURI = $RESTURI  +  "fc_initiator/" + $PWWN.ToLower()
          $InitiatorModificationForJSON = @{
            PARENTTYPE = $PARENTTYPE
            PARENTID = $ActualHost.ID
            MULTIPATHTYPE = $MULTIPATHTYPE
            FAILOVERMODE = $FAILOVERMODE
            SPECIALMODETYPE = $SPECIALMODETYPE
          }

          if ($WhatIf) {
		    write-host "WhatIf (New-OceanStorHost): Associate $PWWN with host $($HostName)" -foreground "Green"
          }
          else {		  
            $result = Invoke-RestMethod -Method "Put" $InitiatorURI -Body (ConvertTo-Json $InitiatorModificationForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
            if ($result -and ($result.error.code -eq 0)) {
              if (-not $Silent) { write-host "Succesfully associated initiator $($pWWN) with host $($HostName)" -foreground "Green"    }      
            }
            else {
              if (-not $Silent) { write-host "ERROR (New-OceanStorHost): Failed to associate initiator $($pWWN) with host $($HostName): $($result.error.description)" -foreground "Red" }
            }
		  } # if ($WhatIf) ... else  
        }

        $PWWN = $StorageHost.SecondpWWN
        if ($PWWN) {
          $InitiatorURI = $RESTURI  +  "fc_initiator/" + $PWWN.ToLower()
          $InitiatorModificationForJSON = @{
            PARENTTYPE = $PARENTTYPE
            PARENTID = $ActualHost.ID
            MULTIPATHTYPE = $MULTIPATHTYPE
            FAILOVERMODE = $FAILOVERMODE
            SPECIALMODETYPE = $SPECIALMODETYPE
          }
              
          if ($WhatIf) {
		    write-host "WhatIf (New-OceanStorHost): Associate $PWWN with host $($HostName)" -foreground "Green"
          }
          else {		  
            $result = Invoke-RestMethod -Method "Put" $InitiatorURI -Body (ConvertTo-Json $InitiatorModificationForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
            if ($result -and ($result.error.code -eq 0)) {
              if (-not $Silent) { write-host "Succesfully associated initiator $($pWWN) with host $($HostName)" -foreground "Green"    }      
            }
            else {
              if (-not $Silent) { write-host "ERROR (New-OceanStorHost): Failed to associate initiator $($pWWN) with host $($HostName): $($result.error.description)" -foreground "Red" }
            }
		  } # if ($WhatIf) ... else  
        }
      } # if ($ActualHost) 
	  
    $ProcessedHosts += 1  
  }
  # --- end host  adding
  
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
}
# --- OceanStor modification section, one big session end ---



  Return($RetVal)

}

