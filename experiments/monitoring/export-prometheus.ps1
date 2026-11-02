param(
    [Parameter(Mandatory=$true)][string]$StartUtc,
    [Parameter(Mandatory=$true)][string]$EndUtc,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$start = [uri]::EscapeDataString($StartUtc)
$end = [uri]::EscapeDataString($EndUtc)
$metrics = @(
    'locust_users',
    'locust_current_requests_per_second',
    'locust_current_failures_per_second',
    'locust_current_response_time_milliseconds',
    'locust_requests_total',
    'locust_failures_total'
)
foreach ($metric in $metrics) {
    $query = [uri]::EscapeDataString($metric)
    $url = "http://127.0.0.1:19090/api/v1/query_range?query=$query&start=$start&end=$end&step=5s"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile (Join-Path $OutputDirectory ("prometheus-" + $metric + '.json'))
}
Write-Output "Saved Prometheus time series in $OutputDirectory"
