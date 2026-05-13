param(
  [Parameter(Mandatory = $true)]
  [string]$ServiceAccountJsonPath
)

$ErrorActionPreference = "Stop"

function Require-Env($Name) {
  $value = [Environment]::GetEnvironmentVariable($Name, "User")
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
  }
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "$Name is not set. Store it as a local environment variable; do not paste secrets into chat."
  }
  Set-Item -Path "env:$Name" -Value $value
  return $value
}

$projectRef = Require-Env "SUPABASE_PROD_PROJECT_REF"
Require-Env "SUPABASE_ACCESS_TOKEN" | Out-Null

$resolvedPath = Resolve-Path -LiteralPath $ServiceAccountJsonPath
$json = Get-Content -LiteralPath $resolvedPath -Raw

try {
  $parsed = $json | ConvertFrom-Json
} catch {
  throw "Service account file is not valid JSON."
}

if ([string]::IsNullOrWhiteSpace($parsed.client_email) -or
    [string]::IsNullOrWhiteSpace($parsed.private_key)) {
  throw "Service account JSON must include client_email and private_key."
}

$tempEnvFile = Join-Path $env:TEMP "pebble-google-play-secrets.env"
try {
  @(
    "GOOGLE_PLAY_PACKAGE_NAME=com.vix.pebble_routines"
    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=$json"
  ) | Set-Content -LiteralPath $tempEnvFile -Encoding utf8

  supabase secrets set --env-file $tempEnvFile --project-ref $projectRef
  supabase functions deploy verify-purchase --project-ref $projectRef
  Write-Output "Google Play verification secrets set and verify-purchase redeployed."
} finally {
  Remove-Item -LiteralPath $tempEnvFile -Force -ErrorAction SilentlyContinue
}
