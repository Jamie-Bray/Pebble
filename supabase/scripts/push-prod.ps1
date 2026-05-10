$ErrorActionPreference = "Stop"

if (-not $env:SUPABASE_ACCESS_TOKEN) {
  throw "SUPABASE_ACCESS_TOKEN is required."
}
if (-not $env:SUPABASE_PROD_PROJECT_REF) {
  throw "SUPABASE_PROD_PROJECT_REF is required."
}
if (-not $env:SUPABASE_PROD_DB_PASSWORD) {
  throw "SUPABASE_PROD_DB_PASSWORD is required."
}

Write-Host "Linking to production project..."
supabase login --token $env:SUPABASE_ACCESS_TOKEN
supabase link --project-ref $env:SUPABASE_PROD_PROJECT_REF --password $env:SUPABASE_PROD_DB_PASSWORD

Write-Host "Pushing production migrations..."
supabase db push

Write-Host "Production migration push complete."
