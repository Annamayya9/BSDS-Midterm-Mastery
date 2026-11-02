param(
    [Parameter(Mandatory=$true)][string]$GatewayUrl,
    [Parameter(Mandatory=$true)][string]$ResultsDirectory,
    [Parameter(Mandatory=$true)][string]$ImageTag
)
$ErrorActionPreference = 'Stop'
$manifest = Join-Path $ResultsDirectory 'run-manifest.csv'
$events = Join-Path $ResultsDirectory 'events.jsonl'
Invoke-RestMethod -Method Get 'http://127.0.0.1:8089/stats/reset' | Out-Null
Start-Sleep -Seconds 2
[pscustomobject]@{stage='autoscale-spike-50'; event='users_requested'; timestamp_utc=[DateTimeOffset]::UtcNow.ToString('o'); users=50; spawn_per_second=25} |
    ConvertTo-Json -Compress | Add-Content -LiteralPath $events -Encoding UTF8
$reply = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8089/swarm' -Body @{user_count=50;spawn_rate=25;host=$GatewayUrl}
if (-not $reply.success) { throw 'Locust rejected the spike.' }
$reached = $false
for ($i=0; $i -lt 30; $i++) {
    $state = Invoke-RestMethod 'http://127.0.0.1:8089/stats/requests'
    if ($state.user_count -eq 50) { $reached = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $reached) { throw 'Locust did not reach 50 users for the spike.' }
Invoke-RestMethod -Method Get 'http://127.0.0.1:8089/stats/reset' | Out-Null
Start-Sleep -Seconds 2
[pscustomobject]@{stage='autoscale-spike-50';start_utc=[DateTimeOffset]::UtcNow.ToString('o');users=50;spawn_per_second=25;file='tiny.txt';wait_seconds=1;send_loss_percent=0;receive_loss_percent=0;gateway_tasks='see recorder';backend_tasks='see recorder';image_tag=$ImageTag} |
    Export-Csv -NoTypeInformation -Append -Path $manifest
Write-Output "Started 50-user spike measurement at $([DateTimeOffset]::UtcNow.ToString('o'))"
for ($minute=1; $minute -le 3; $minute++) {
    Start-Sleep -Seconds 60
    Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:8089/stats/requests/csv' -OutFile (Join-Path $ResultsDirectory ("autoscale-spike-50-minute-" + $minute + '.csv'))
    Write-Output "Completed minute $minute of the 50-user spike"
}
Write-Output 'Spike is ready for screenshots; Locust remains running.'
