param(
    [Parameter(Mandatory=$true)][string]$StartUtc,
    [Parameter(Mandatory=$true)][string]$EndUtc,
    [Parameter(Mandatory=$true)][string]$LoadBalancer,
    [Parameter(Mandatory=$true)][string]$TargetGroup,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
function New-MetricQuery($id, $namespace, $metricName, $dimensions, $statistic) {
    return @{
        Id = $id
        MetricStat = @{
            Metric = @{ Namespace = $namespace; MetricName = $metricName; Dimensions = @($dimensions) }
            Period = 60
            Stat = $statistic
        }
        ReturnData = $true
    }
}

$gateway = @(@{Name='ClusterName';Value='file-transfer'}, @{Name='ServiceName';Value='gateway'})
$backend = @(@{Name='ClusterName';Value='file-transfer'}, @{Name='ServiceName';Value='backend'})
$lb = @(@{Name='LoadBalancer';Value=$LoadBalancer})
$lbTarget = @(@{Name='LoadBalancer';Value=$LoadBalancer}, @{Name='TargetGroup';Value=$TargetGroup})
$queries = @(
    (New-MetricQuery 'gateway_cpu' 'AWS/ECS' 'CPUUtilization' $gateway 'Average')
    (New-MetricQuery 'backend_cpu' 'AWS/ECS' 'CPUUtilization' $backend 'Average')
    (New-MetricQuery 'gateway_memory' 'AWS/ECS' 'MemoryUtilization' $gateway 'Average')
    (New-MetricQuery 'backend_memory' 'AWS/ECS' 'MemoryUtilization' $backend 'Average')
    (New-MetricQuery 'alb_requests_per_target' 'AWS/ApplicationELB' 'RequestCountPerTarget' $lbTarget 'Sum')
    (New-MetricQuery 'alb_requests' 'AWS/ApplicationELB' 'RequestCount' $lb 'Sum')
    (New-MetricQuery 'alb_target_5xx' 'AWS/ApplicationELB' 'HTTPCode_Target_5XX_Count' $lb 'Sum')
    (New-MetricQuery 'alb_5xx' 'AWS/ApplicationELB' 'HTTPCode_ELB_5XX_Count' $lb 'Sum')
)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$queryPath = Join-Path $OutputDirectory 'cloudwatch-queries.json'
$resultPath = Join-Path $OutputDirectory 'cloudwatch-metrics.json'
[IO.File]::WriteAllText($queryPath, (ConvertTo-Json -InputObject $queries -Depth 12), $utf8)
$queryUri = 'file://' + ($queryPath -replace '\\','/')
$result = & aws cloudwatch get-metric-data --region us-east-1 --metric-data-queries $queryUri --start-time $StartUtc --end-time $EndUtc --scan-by TimestampAscending --output json
if ($LASTEXITCODE -ne 0) { throw 'CloudWatch metric query failed.' }
[IO.File]::WriteAllText($resultPath, ($result -join "`n"), $utf8)
Write-Output "Saved $resultPath"
