$URL = "https://lxvrvrrxdjbrjwsxzppl.supabase.co"
$ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4dnJ2cnJ4ZGpicmp3c3h6cHBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU1Nzk3ODQsImV4cCI6MjA5MTE1NTc4NH0.-JfDi3LS2JOFYN2khc2fCeyK6cmr8gKOVwjBcVxxWts"
$CLIENT = "972477323709-jidm32kvrj3sk77cr38142qmnj521407.apps.googleusercontent.com"

$arguments = @(
  "run",
  "--dart-define=APP_ENV=staging",
  "--dart-define=SUPABASE_URL=$URL",
  "--dart-define=SUPABASE_ANON_KEY=$ANON",
  "--dart-define=SUPABASE_GOOGLE_WEB_CLIENT_ID=$CLIENT"
)

# Optional: set PEBBLE_STAGING_SENTRY_DSN to test crash reporting in staging.
if (-not [string]::IsNullOrWhiteSpace($env:PEBBLE_STAGING_SENTRY_DSN)) {
  $arguments += "--dart-define=SENTRY_DSN=$($env:PEBBLE_STAGING_SENTRY_DSN)"
}

flutter @arguments


