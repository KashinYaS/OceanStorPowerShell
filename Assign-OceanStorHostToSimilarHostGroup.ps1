Function Assign-OceanStorHostToSimilarHostGroup {
  [CmdletBinding(DefaultParameterSetName="LUNGroupName")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='LUNGroupName')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='LUNGroupName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='LUNGroupName')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='LUNGroupName')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='LUNGroupName')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='LUNGroupName')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='LUNGroupName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Host and Host Group name(s)",ParameterSetName='LUNGroupName')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
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

  # Get LUN Groups and mapping views needed to associate
  $Hosts       = Get-OceanStorHost      -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True | where {$Name.ToUpper() -contains $_.NAME.ToUpper()}
  $HostGroups  = Get-OceanStorHostGroup -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True | where {$Name.ToUpper() -contains $_.NAME.ToUpper()}
    
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

	$URI = $RESTURI  + "hostgroup/associate"

    $RetVal = @() 

	$ProcessedLUNGroup = 0
    foreach ($CurrentName in $Name) {
      if (-not $Silent) {
        $PercentCompletedLUNGroup = [math]::Floor($ProcessedLUNGroup / $Name.Count * 100)
	    Write-Progress -Activity "Adding Host to Host Group" -CurrentOperation "$($CurrentName)" -PercentComplete $PercentCompletedLUNGroup
	  }
	  $CurrentHost = $Hosts | where {$_.NAME.ToUpper() -eq $CurrentName.ToUpper()}
      if (-not ( $CurrentHost )) {
	    # No actual Host found
		if (-not $Silent) {
		  write-host "ERROR (Assign-OceanStorHostToSimilarHostGroup): Host $($CurrentName) not found - skipping association" -foreground "Red"
		}
	  }
	  else {
	    # Host found, let's check Host Group
		$CurrentHostGroup = $HostGroups | where {$_.NAME.ToUpper() -eq $CurrentName.ToUpper()}
		if (-not ( $CurrentHostGroup )) {
		  if (-not $Silent) {
		    write-host "ERROR (Assign-OceanStorHostToSimilarHostGroup): Host Group $($CurrentName) not found - skipping association" -foreground "Red"
		  }
        }
		else {
		  # Host and Host Group both exist - associate them
		  if ($WhatIf) {
		    write-host "WhatIf (Assign-OceanStorHostToSimilarHostGroup): Associate Host ($($CurrentName), ID $($CurrentHost.ID)) and Host Group ($($CurrentName), ID $($CurrentHostGroup.ID))" -foreground "Green"
		  }
		  else {
			$HostAssociationForJSON = @{
              ID = $CurrentHostGroup.ID
              ASSOCIATEOBJTYPE = 21
              ASSOCIATEOBJID = $CurrentHost.ID
            }
	        # ASSOCIATEOBJTYPE: 14 - Host group, 256 - LUN group, 257 - Port group, 21 - Host
            $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $HostAssociationForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
            if ($result -and ($result.error.code -eq 0)) {
              if (-not $Silent) {
			    write-host "Host and group $($CurrentName) association added" -foreground "Green"
			  }
              $RetVal += $result.data
            }
            else {
			  if (-not $Silent) {
			    write-host "ERROR (Assign-OceanStorHostToSimilarHostGroup): Failed to associate Host ($($CurrentName), ID $($CurrentHost.ID)) and Host Group ($($CurrentName), ID $($CurrentHostGroup.ID)): $($result.error.description)" -foreground "Red"
              }
            }
		  }
		} # else (-not ( $CurrentHostGroup ))
	  } # else (-not (  $CurrentHost  ))
	  $ProcessedLUNGroup += 1
    } #foreach $CurrentName
  
    $URI = $RESTURI  + "sessions"
    $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession  
  }
  
  Return($RetVal)
}

