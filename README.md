# Public Site Data Scripts

CSV files in `outputs` are the source of truth. After updating those CSV files,
run these scripts to regenerate and verify the browser data used by `public_site`.

## 1. Regenerate Browser Data

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_public_site_data.ps1
```

This reads:

- `outputs/public_search_index_v01.csv`
- `outputs/public_records_v01.csv`

And writes:

- `public_site/data/search_index.js`
- `public_site/data/public_records.js`

## 2. Verify The Site Data

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify_public_site.ps1
```

This checks:

- JavaScript syntax for `app.js`
- JavaScript syntax for `record.js`
- row counts between CSV and browser data
- presence of the public label `中国代表権・承認競争`
- presence of the sample detail record `mofa_100_013444`

The verification report is written to:

- `outputs/public_site_verify_report.txt`
