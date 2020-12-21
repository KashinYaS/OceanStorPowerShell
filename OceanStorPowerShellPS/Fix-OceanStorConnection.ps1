Function Fix-OceanStorConnection {
  # --- prepare to connect with TLS 1.2 and ignore self-signed certificate of OceanStor ---
  [Net.ServicePointManager]::SecurityProtocol =[Net.SecurityProtocolType]::Tls12

  if (-not ("TrustAllCertsPolicy" -as [type])) {
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
  }
  
  [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
  
  # --- end TLS and Cert preparation ---
}
