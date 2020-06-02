Function Get-OceanStorHost {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True,Position=6,HelpMessage = "Host name",ParameterSetName='Hostname')][String]$Name = $null,
    [PARAMETER(Mandatory=$True,Position=6,HelpMessage = "Host ID",ParameterSetName='ID')][int]$ID = $null
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

    # --- getting existing hosts 
    if (-not $ID) {
	  $URI = $RESTURI  + "host"
	}
	else {
	  $URI = $RESTURI  + "host/" + $ID
	}
	
    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      if (-not $Name) {
	    $RetVal = $result.data		
	  }
	  else {
	    $RetVal = $result.data | where {$_.Name.ToUpper() -eq $Name.ToUpper()}
		if ((-not $RetVal) -and (-not $Silent)) {
		  write-host "ERROR (Get-OceanStorHosts): Host $($Name) not found" -foreground "Red"
		}
	  }
    }
    else {
      $RetVal = $null
	  if (-not $Silent) {
	    write-host "ERROR (Get-OceanStorHosts): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}

