param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

$OutputsDir = Join-Path $Root 'outputs'
$SiteDataDir = Join-Path $Root 'public_site\data'
$SummaryPath = Join-Path $OutputsDir 'public_site_data_build_summary.txt'

$SearchCsv = Join-Path $OutputsDir 'public_search_index_v01.csv'
$RecordsCsv = Join-Path $OutputsDir 'public_records_v01.csv'
$SearchJs = Join-Path $SiteDataDir 'search_index.js'
$RecordsJs = Join-Path $SiteDataDir 'public_records.js'

function Convert-CsvToJavascriptData {
  param(
    [string]$CsvPath,
    [string]$OutputPath,
    [string]$GlobalVariableName
  )

  if (-not (Test-Path -LiteralPath $CsvPath)) {
    throw "Missing required CSV: $CsvPath"
  }

  $rows = Import-Csv -LiteralPath $CsvPath
  $json = $rows | ConvertTo-Json -Depth 8
  $content = "window.$GlobalVariableName = $json;"
  Set-Content -LiteralPath $OutputPath -Value $content -Encoding UTF8

  [pscustomobject]@{
    csv = $CsvPath
    output = $OutputPath
    global_variable = $GlobalVariableName
    row_count = @($rows).Count
  }
}

New-Item -ItemType Directory -Force -Path $SiteDataDir | Out-Null

$results = @()
$results += Convert-CsvToJavascriptData -CsvPath $SearchCsv -OutputPath $SearchJs -GlobalVariableName 'SEARCH_INDEX'
$results += Convert-CsvToJavascriptData -CsvPath $RecordsCsv -OutputPath $RecordsJs -GlobalVariableName 'PUBLIC_RECORDS'

$timestamp = Get-Date
$summary = @(
  'public site data build summary',
  ('created_at: ' + $timestamp.ToString('yyyy-MM-dd HH:mm:ss zzz')),
  '',
  'inputs:',
  ('- ' + $SearchCsv),
  ('- ' + $RecordsCsv),
  '',
  'outputs:',
  ('- ' + $SearchJs),
  ('- ' + $RecordsJs),
  '',
  'row_counts:'
)

foreach ($r in $results) {
  $summary += "- $($r.global_variable): $($r.row_count)"
}

$summary | Set-Content -LiteralPath $SummaryPath -Encoding UTF8

$results | Format-Table -AutoSize
Write-Host ""
Write-Host "Summary written to: $SummaryPath"
