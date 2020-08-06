Function Assign-OceanStorHostGroupToSimilarMappingView {
  [CmdletBinding(DefaultParameterSetName="HostGroupName")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='HostGroupName')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='HostGroupName')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='HostGroupName')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='HostGroupName')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='HostGroupName')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='HostGroupName')][switch]$WhatIf,	
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='HostGroupName')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True, Position=6,HelpMessage = "Host Group and Mapping view name",ParameterSetName='HostGroupName')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
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

  # Get Host Groups and mapping views needed to associate
  $HostGroups   = Get-OceanStorHostGroup   -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True | where {$Name.ToUpper() -contains $_.NAME.ToUpper()}
  $MappingViews = Get-OceanStorMappingView -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True | where {$Name.ToUpper() -contains $_.NAME.ToUpper()}
    
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

	$URI = $RESTURI  + "mappingview/create_associate"

    $RetVal = @() 

	$ProcessedHostGroup = 0
    foreach ($CurrentName in $Name) {
      if (-not $Silent) {
        $PercentCompletedHostGroup = [math]::Floor($ProcessedHostGroup / $Name.Count * 100)
	    Write-Progress -Activity "Adding Host Groups" -CurrentOperation "$($CurrentName)" -PercentComplete $PercentCompletedHostGroup
	  }
	  $CurrentHostGroup = $HostGroups | where {$_.NAME.ToUpper() -eq $CurrentName.ToUpper()}
      if (-not ( $CurrentHostGroup )) {
	    # No actual Host Group found
		if (-not $Silent) {
		  write-host "ERROR (Assign-OceanStorHostGroupToSimilarMappingView): Host Group $($CurrentName) not found - skipping association" -foreground "Red"
		}
	  }
	  else {
	    # Host Group found, let's check Mapping View
		$CurrentMappingView = $MappingViews | where {$_.NAME.ToUpper() -eq $CurrentName.ToUpper()}
		if (-not ( $CurrentMappingView )) {
		  if (-not $Silent) {
		    write-host "ERROR (Assign-OceanStorHostGroupToSimilarMappingView): Mapping View $($CurrentName) not found - skipping association" -foreground "Red"
		  }
        }
		else {
		  # Host Group and Mapping View exist - associate them
		  if ($WhatIf) {
		    write-host "WhatIf (Assign-OceanStorHostGroupToSimilarMappingView): Associate Host Group ($($CurrentName), ID $($CurrentHostGroup.ID)) and Mapping View ($($CurrentName), ID $($CurrentMappingView.ID))" -foreground "Green"
		  }
		  else {
            $MappingViewAssocForJSON = @{
              ID = $CurrentMappingView.ID
		      ASSOCIATEOBJTYPE = 14
		      ASSOCIATEOBJID = $CurrentHostGroup.ID
            }
	        # ASSOCIATEOBJTYPE: 14 - Host group, 256 - LUN group, 257 - Port group
            $result = Invoke-RestMethod -Method "Post" -Uri $URI -Body (ConvertTo-Json $MappingViewAssocForJSON) -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
            if ($result -and ($result.error.code -eq 0)) {
              if (-not $Silent) {
			    write-host "Host Group ($($CurrentName), ID $($CurrentHostGroup.ID)) associated with Mapping View ($($CurrentName), ID $($CurrentMappingView.ID)) " -foreground "Green"
			  }
              $RetVal += $result.data
            }
            else {
			  if (-not $Silent) {
			    write-host "ERROR (Assign-OceanStorHostGroupToSimilarMappingView): Failed to associate Host Group ($($CurrentName), ID $($CurrentHostGroup.ID)) and Mapping View ($($CurrentName), ID $($CurrentMappingView.ID)): $($result.error.code); $($result.error.description)" -foreground "Red"
              }
            }

		  }
		} # else (-not ( $CurrentMappingView ))
	  } # else (-not (  $CurrentHostGroup  ))
	  $ProcessedHostGroup += 1
    } #foreach $CurrentName
  
    $URI = $RESTURI  + "sessions"
    $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession  
  }
  
  Return($RetVal)
}

