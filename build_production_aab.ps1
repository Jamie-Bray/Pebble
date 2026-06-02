param(
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Require-Env($Name) {
  $value = [Environment]::GetEnvironmentVariable($Name, "User")
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
  }
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "$Name is not set. Store it as a local environment variable; do not commit production values."
  }
  return $value
}

$supabaseUrl = Require-Env "PEBBLE_PROD_SUPABASE_URL"
$supabaseAnonKey = Require-Env "PEBBLE_PROD_SUPABASE_ANON_KEY"
$revenueCatAndroidApiKey = Require-Env "PEBBLE_PROD_REVENUECAT_ANDROID_API_KEY"
if (-not $revenueCatAndroidApiKey.StartsWith("goog_")) {
  throw "PEBBLE_PROD_REVENUECAT_ANDROID_API_KEY must be the RevenueCat Android SDK key starting with 'goog_', not a test or secret key."
}
$googleWebClientId = Require-Env "PEBBLE_PROD_GOOGLE_WEB_CLIENT_ID"
$accountDeletionUrl = [Environment]::GetEnvironmentVariable(
  "PEBBLE_ACCOUNT_DELETION_URL",
  "User"
)

$arguments = @(
  "build",
  "appbundle",
  "--release",
  "--dart-define=APP_ENV=production",
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey",
  "--dart-define=REVENUECAT_ANDROID_API_KEY=$revenueCatAndroidApiKey",
  "--dart-define=REVENUECAT_ENTITLEMENT_ID=personal_premium",
  "--dart-define=SUPABASE_GOOGLE_WEB_CLIENT_ID=$googleWebClientId"
)

if (-not [string]::IsNullOrWhiteSpace($accountDeletionUrl)) {
  $arguments += "--dart-define=PEBBLE_ACCOUNT_DELETION_URL=$accountDeletionUrl"
}

if ($DryRun) {
  Write-Output "Would build production Android App Bundle."
  Write-Output "Required production env vars are present, including Google sign-in."
  if ([string]::IsNullOrWhiteSpace($accountDeletionUrl)) {
    Write-Output "PEBBLE_ACCOUNT_DELETION_URL is not set; the app will use its in-app deletion request path only."
  }
  exit 0
}

& flutter @arguments
