param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

$OutputsDir = Join-Path $Root 'outputs'
$DownloadsDir = Join-Path $Root 'public_site\downloads'
$SummaryPath = Join-Path $OutputsDir 'public_site_downloads_build_summary.txt'

New-Item -ItemType Directory -Force -Path $DownloadsDir | Out-Null

$files = @(
  @{ source = 'public_records_v01.csv'; target = 'public_records.csv'; description = 'One row per public archival record' },
  @{ source = 'record_tags_v01.csv'; target = 'record_tags.csv'; description = 'Many-to-many record/tag table' },
  @{ source = 'public_tag_labels_v06.csv'; target = 'public_tag_labels.csv'; description = 'Public tag labels used by the website' },
  @{ source = 'public_search_index_v01.csv'; target = 'public_search_index.csv'; description = 'One-row search index used by the website' },
  @{ source = 'review_flags_v01.csv'; target = 'review_flags.csv'; description = 'Open review flags for ambiguous or historical entities' },
  @{ source = 'controlled_vocabulary_regions_v02.csv'; target = 'controlled_vocabulary_regions.csv'; description = 'Controlled vocabulary for regions' },
  @{ source = 'controlled_vocabulary_entities_v08.csv'; target = 'controlled_vocabulary_entities.csv'; description = 'Controlled vocabulary for entities' },
  @{ source = 'controlled_vocabulary_organizations_v08.csv'; target = 'controlled_vocabulary_organizations.csv'; description = 'Controlled vocabulary for organizations' },
  @{ source = 'controlled_vocabulary_events_v12.csv'; target = 'controlled_vocabulary_events.csv'; description = 'Controlled vocabulary for events' },
  @{ source = 'controlled_vocabulary_blocs_v02.csv'; target = 'controlled_vocabulary_blocs.csv'; description = 'Controlled vocabulary for blocs' },
  @{ source = 'controlled_vocabulary_keywords_v17.csv'; target = 'controlled_vocabulary_keywords.csv'; description = 'Controlled vocabulary for keywords' },
  @{ source = 'controlled_vocabulary_analytical_contexts_v05.csv'; target = 'controlled_vocabulary_analytical_contexts.csv'; description = 'Controlled vocabulary for analytical contexts' }
)

$manifestRows = foreach ($file in $files) {
  $sourcePath = Join-Path $OutputsDir $file.source
  $targetPath = Join-Path $DownloadsDir $file.target
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Missing download source: $sourcePath"
  }

  Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
  $rowCount = @((Import-Csv -LiteralPath $targetPath)).Count
  $item = Get-Item -LiteralPath $targetPath

  [pscustomobject]@{
    file_name = $file.target
    source_file = $file.source
    description = $file.description
    row_count = $rowCount
    size_bytes = $item.Length
  }
}

$manifestPath = Join-Path $DownloadsDir 'manifest.csv'
$manifestRows | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8

$summary = @(
  'public site downloads build summary',
  ('created_at: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')),
  ('downloads_dir: ' + $DownloadsDir),
  '',
  'files:'
)

foreach ($row in $manifestRows) {
  $summary += "- $($row.file_name): $($row.row_count) rows, $($row.size_bytes) bytes"
}

$summary += ''
$summary += ('manifest: ' + $manifestPath)
$summary | Set-Content -LiteralPath $SummaryPath -Encoding UTF8

$manifestRows | Format-Table -AutoSize
Write-Host ""
Write-Host "Manifest written to: $manifestPath"
Write-Host "Summary written to: $SummaryPath"
