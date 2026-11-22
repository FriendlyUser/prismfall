# Creates the Android release keystore and (if GitHub CLI is logged in inside the repo)
# stores it as the secrets the Build & Release workflow expects.
#   ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS
# Usage (from the repo root):  powershell -ExecutionPolicy Bypass -File tools/android_keystore.ps1
param(
    [string]$Alias = "prismfall",
    [string]$Keystore = "prismfall-release.keystore"
)
$ErrorActionPreference = "Stop"
if (Test-Path $Keystore) { throw "$Keystore already exists - refusing to overwrite your signing key." }
$secure = Read-Host "Keystore password (min 6 chars)" -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
keytool -genkeypair -v -keystore $Keystore -alias $Alias -keyalg RSA -keysize 2048 -validity 10000 `
    -storepass $plain -keypass $plain -dname "CN=Prismfall, O=Prismfall, C=US"
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $Keystore)))
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $b64 | gh secret set ANDROID_KEYSTORE_BASE64
    $plain | gh secret set ANDROID_KEYSTORE_PASSWORD
    $Alias | gh secret set ANDROID_KEY_ALIAS
    Write-Host "GitHub secrets set."
} else {
    Write-Host "Install GitHub CLI or add these repository secrets manually:"
    Write-Host "  ANDROID_KEYSTORE_BASE64 = (base64 of $Keystore)"
    Write-Host "  ANDROID_KEYSTORE_PASSWORD = (your password)"
    Write-Host "  ANDROID_KEY_ALIAS = $Alias"
}
Write-Host "Back up $Keystore and its password somewhere safe: Google Play needs the same key for every update. Never commit it."
