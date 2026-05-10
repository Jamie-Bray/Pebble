$ErrorActionPreference = "Stop"

if (-not $env:SUPABASE_ACCESS_TOKEN) {
  throw "SUPABASE_ACCESS_TOKEN is required."
}
if (-not $env:SUPABASE_STAGING_PROJECT_REF) {
  throw "SUPABASE_STAGING_PROJECT_REF is required."
}
if (-not $env:SUPABASE_STAGING_DB_PASSWORD) {
  throw "SUPABASE_STAGING_DB_PASSWORD is required."
}

Write-Host "Linking to staging project..."
supabase login --token $env:SUPABASE_ACCESS_TOKEN
supabase link --project-ref $env:SUPABASE_STAGING_PROJECT_REF --password $env:SUPABASE_STAGING_DB_PASSWORD

Write-Host "Pushing staging migrations..."
supabase db push

Write-Host "Staging migration push complete."
