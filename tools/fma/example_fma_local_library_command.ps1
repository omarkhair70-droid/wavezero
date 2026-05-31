# Example only. Replace these paths and <LAN-IP> with your local machine values.
# Keep fma_small.zip, extracted MP3s, and generated local catalog/report files outside Git.

$WorkRoot = "C:\Users\<you>\Desktop\wavezero-fma-work\fma\data"
$MetadataDir = "$WorkRoot\fma_metadata"
$AudioDir = "$WorkRoot\wavezero_fma_green_small_audio"
$CatalogJson = "$MetadataDir\wavezero_fma_green_small_catalog.json"
$ReportCsv = "$MetadataDir\wavezero_fma_green_small_import_report.csv"
$AudioBaseUrl = "http://<LAN-IP>:8091"

python tools\fma\build_fma_green_small_local_library.py `
  --metadata-dir $MetadataDir `
  --fma-small-zip "$WorkRoot\fma_small.zip" `
  --input-csv "$MetadataDir\wavezero_fma_green_candidates_all_v2.csv" `
  --output-audio-dir $AudioDir `
  --output-catalog-json $CatalogJson `
  --output-report-csv $ReportCsv `
  --audio-base-url $AudioBaseUrl
