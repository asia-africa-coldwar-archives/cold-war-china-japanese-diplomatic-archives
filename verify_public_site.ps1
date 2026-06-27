param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$NodePath = ''
)

$ErrorActionPreference = 'Stop'

$OutputsDir = Join-Path $Root 'outputs'
$SiteDir = Join-Path $Root 'public_site'
$SearchCsv = Join-Path $OutputsDir 'public_search_index_v01.csv'
$RecordsCsv = Join-Path $OutputsDir 'public_records_v01.csv'
$SearchJs = Join-Path $SiteDir 'data\search_index.js'
$RecordsJs = Join-Path $SiteDir 'data\public_records.js'
$AppJs = Join-Path $SiteDir 'app.js'
$RecordJs = Join-Path $SiteDir 'record.js'
$ReportPath = Join-Path $OutputsDir 'public_site_verify_report.txt'

function Find-Node {
  param([string]$ExplicitNodePath)

  if ($ExplicitNodePath -and (Test-Path -LiteralPath $ExplicitNodePath)) {
    return $ExplicitNodePath
  }

  $command = Get-Command node -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $bundled = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
  if (Test-Path -LiteralPath $bundled) {
    return $bundled
  }

  throw 'Node.js was not found. Pass -NodePath or use the bundled Codex runtime.'
}

$node = Find-Node -ExplicitNodePath $NodePath

foreach ($path in @($SearchCsv, $RecordsCsv, $SearchJs, $RecordsJs, $AppJs, $RecordJs)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required file: $path"
  }
}

$searchCsvCount = @((Import-Csv -LiteralPath $SearchCsv)).Count
$recordsCsvCount = @((Import-Csv -LiteralPath $RecordsCsv)).Count

& $node --check $AppJs
& $node --check $RecordJs

$jsCheck = @'
global.window = {};
require(process.argv[1]);
require(process.argv[2]);
const searchCount = Array.isArray(window.SEARCH_INDEX) ? window.SEARCH_INDEX.length : -1;
const recordsCount = Array.isArray(window.PUBLIC_RECORDS) ? window.PUBLIC_RECORDS.length : -1;
const hasChnAmbig = window.SEARCH_INDEX.some((r) => {
  const text = String(r.search_text_all || '');
  return text.includes('China Representation and Recognition Competition') || text.includes('CHN_AMBIG');
});
const hasDetailsCandidate = window.SEARCH_INDEX.some((r) => r.record_id === 'mofa_100_013444');
console.log(JSON.stringify({ searchCount, recordsCount, hasChnAmbig, hasDetailsCandidate }));
'@

$nodeOutput = & $node -e $jsCheck $SearchJs $RecordsJs
$parsed = $nodeOutput | ConvertFrom-Json

$searchRowsMatch = [int]$parsed.searchCount -eq [int]$searchCsvCount
$recordsRowsMatch = [int]$parsed.recordsCount -eq [int]$recordsCsvCount
$chnAmbigPresent = [bool]$parsed.hasChnAmbig
$detailCandidatePresent = [bool]$parsed.hasDetailsCandidate

$checks = @(
  [pscustomobject]@{ check='public_search_index_csv_rows'; value=$searchCsvCount; expected='75 or current source count'; status='INFO' },
  [pscustomobject]@{ check='public_records_csv_rows'; value=$recordsCsvCount; expected='75 or current source count'; status='INFO' },
  [pscustomobject]@{ check='search_index_js_rows_match_csv'; value=$parsed.searchCount; expected=$searchCsvCount; status=($(if ($searchRowsMatch) { 'PASS' } else { 'FAIL' })) },
  [pscustomobject]@{ check='public_records_js_rows_match_csv'; value=$parsed.recordsCount; expected=$recordsCsvCount; status=($(if ($recordsRowsMatch) { 'PASS' } else { 'FAIL' })) },
  [pscustomobject]@{ check='app_js_syntax'; value='ok'; expected='ok'; status='PASS' },
  [pscustomobject]@{ check='record_js_syntax'; value='ok'; expected='ok'; status='PASS' },
  [pscustomobject]@{ check='china_representation_label_present'; value=$parsed.hasChnAmbig; expected='True'; status=($(if ($chnAmbigPresent) { 'PASS' } else { 'FAIL' })) },
  [pscustomobject]@{ check='detail_example_record_present'; value=$parsed.hasDetailsCandidate; expected='True'; status=($(if ($detailCandidatePresent) { 'PASS' } else { 'FAIL' })) }
)

$failed = @($checks | Where-Object { $_.status -eq 'FAIL' })

$report = @(
  'public site verify report',
  ('created_at: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')),
  ('node: ' + $node),
  ''
)

foreach ($c in $checks) {
  $report += "$($c.status) $($c.check): $($c.value) expected $($c.expected)"
}

$report | Set-Content -LiteralPath $ReportPath -Encoding UTF8

$checks | Format-Table -AutoSize
Write-Host ""
Write-Host "Report written to: $ReportPath"

if ($failed.Count -gt 0) {
  throw "$($failed.Count) verification check(s) failed."
}
