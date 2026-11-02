param(
    [Parameter(Mandatory=$true)][string]$StartUtc,
    [Parameter(Mandatory=$true)][string]$EndUtc,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$startMs = [DateTimeOffset]::Parse($StartUtc).ToUnixTimeMilliseconds()
$endMs = [DateTimeOffset]::Parse($EndUtc).ToUnixTimeMilliseconds()
$utf8 = New-Object System.Text.UTF8Encoding($false)
$sources = @(
    @{ name='backend-simulated-loss'; group='/ecs/file-transfer-backend'; pattern='Simulated' },
    @{ name='backend-overload'; group='/ecs/file-transfer-backend'; pattern='Overloaded' },
    @{ name='gateway-missing-chunk-retries'; group='/ecs/file-transfer-gateway'; pattern='retrying' }
)
foreach ($source in $sources) {
    $output = & aws logs filter-log-events --region us-east-1 --log-group-name $source.group --start-time $startMs --end-time $endMs --filter-pattern $source.pattern --output json
    if ($LASTEXITCODE -ne 0) { throw "CloudWatch Logs query failed: $($source.name)" }
    $path = Join-Path $OutputDirectory ("logs-" + $source.name + '.json')
    [IO.File]::WriteAllText($path, ($output -join "`n"), $utf8)
    Write-Output "Saved $path"
}
