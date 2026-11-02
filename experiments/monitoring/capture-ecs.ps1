param([Parameter(Mandatory=$true)][string]$OutputPath)

# Capture actual task counts; one-minute CloudWatch CPU metrics are collected separately.
while ($true) {
    $timestamp = [DateTimeOffset]::UtcNow.ToString('o')
    $raw = & aws ecs describe-services --region us-east-1 --cluster file-transfer --services gateway backend --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        try {
            $response = ($raw -join "`n") | ConvertFrom-Json
            foreach ($service in $response.services) {
                [pscustomobject]@{
                    timestamp_utc = $timestamp
                    service = $service.serviceName
                    desired = $service.desiredCount
                    running = $service.runningCount
                    pending = $service.pendingCount
                    deployment_state = ($service.deployments | ForEach-Object { $_.rolloutState }) -join ','
                } | ConvertTo-Json -Compress | Add-Content -LiteralPath $OutputPath -Encoding UTF8
            }
        } catch {
            [pscustomobject]@{ timestamp_utc = $timestamp; error = $_.Exception.Message } |
                ConvertTo-Json -Compress | Add-Content -LiteralPath $OutputPath -Encoding UTF8
        }
    } else {
        [pscustomobject]@{ timestamp_utc = $timestamp; error = ($raw -join ' ') } |
            ConvertTo-Json -Compress | Add-Content -LiteralPath $OutputPath -Encoding UTF8
    }
    Start-Sleep -Seconds 30
}
