param(
    [Parameter(Mandatory=$true)][string]$WidgetPath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $WidgetPath).Path
$uri = 'file://' + ($resolved -replace '\\', '/')
$image = & aws cloudwatch get-metric-widget-image --region us-east-1 --metric-widget $uri --output-format png --output text --query MetricWidgetImage
if ($LASTEXITCODE -ne 0) { throw 'CloudWatch graph export failed.' }
$bytes = [Convert]::FromBase64String(($image -join '').Trim())
if ($bytes.Length -lt 8 -or $bytes[0] -ne 137 -or $bytes[1] -ne 80) { throw 'CloudWatch did not return a PNG.' }
[IO.File]::WriteAllBytes($OutputPath, $bytes)
Write-Output "Saved CloudWatch-rendered graph: $OutputPath"
