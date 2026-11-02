param(
    [Parameter(Mandatory=$true)][string]$GatewayUrl,
    [Parameter(Mandatory=$true)][string]$ResultsDirectory,
    [Parameter(Mandatory=$true)][string]$ImageTag
)
$ErrorActionPreference = 'Stop'
$manifest = Join-Path $ResultsDirectory 'run-manifest.csv'
$events = Join-Path $ResultsDirectory 'events.jsonl'

function Set-Load([string]$name, [int]$users, [int]$spawnRate) {
    [pscustomobject]@{stage=$name; event='users_requested'; timestamp_utc=[DateTimeOffset]::UtcNow.ToString('o'); users=$users; spawn_per_second=$spawnRate} |
        ConvertTo-Json -Compress | Add-Content -LiteralPath $events -Encoding UTF8
    $body = @{user_count=$users; spawn_rate=$spawnRate; host=$GatewayUrl}
    $reply = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8089/swarm' -Body $body
    if (-not $reply.success) { throw "Locust rejected stage $name" }
    for ($i=0; $i -lt 30; $i++) {
        $state = Invoke-RestMethod 'http://127.0.0.1:8089/stats/requests'
        if ($state.user_count -eq $users) { return }
        Start-Sleep -Seconds 2
    }
    throw "Locust did not reach $users users for $name"
}

function Begin-Measurement([string]$name, [int]$users, [int]$spawnRate) {
    Invoke-RestMethod -Method Get 'http://127.0.0.1:8089/stats/reset' | Out-Null
    Start-Sleep -Seconds 2
    [pscustomobject]@{stage=$name;start_utc=[DateTimeOffset]::UtcNow.ToString('o');users=$users;spawn_per_second=$spawnRate;file='tiny.txt';wait_seconds=1;send_loss_percent=0;receive_loss_percent=0;gateway_tasks='see recorder';backend_tasks='see recorder';image_tag=$ImageTag} |
        Export-Csv -NoTypeInformation -Append -Path $manifest
    Write-Output "Started $name measurement: $users users at $([DateTimeOffset]::UtcNow.ToString('o'))"
}

function Save-Stats([string]$name) {
    Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:8089/stats/requests/csv' -OutFile (Join-Path $ResultsDirectory ($name + '.csv'))
}

Set-Load 'autoscale-ramp-5' 5 1
Begin-Measurement 'autoscale-ramp-5' 5 1
Start-Sleep -Seconds 60
Save-Stats 'autoscale-ramp-5'

Set-Load 'autoscale-ramp-20' 20 2
Begin-Measurement 'autoscale-ramp-20' 20 2
Start-Sleep -Seconds 60
Save-Stats 'autoscale-ramp-20'

Set-Load 'autoscale-ramp-50' 50 5
Begin-Measurement 'autoscale-ramp-50' 50 5
for ($minute=1; $minute -le 3; $minute++) {
    Start-Sleep -Seconds 60
    Save-Stats ("autoscale-ramp-50-minute-" + $minute)
    Write-Output "Completed minute $minute of the 50-user ramp plateau"
}
Write-Output 'Ramp plateau is ready for screenshots; Locust remains running.'
