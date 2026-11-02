# Midterm Mastery: 4–5 minute presentation guide

Use this as speaking notes and select the linked visuals for slides or screen sharing. The assignment asks for a presentation; the report and repository provide supporting evidence and do not by themselves establish that the presentation requirement has been met. Check the course submission instructions for any separate file or format requirements.

## 0:00–0:40 — Setup and question

“I evaluated an AWS file-sharing service with three experiments: load and recovery, UDP loss, and autoscaling. The HTTP gateway and UDP backend ran on ECS. To control the workload, Locust repeatedly requested the same 65-byte file; each user waited one second between requests. I recorded client throughput, HTTP failures, and end-to-end response time, along with CloudWatch and ECS scaling data. For p95, 95% of measured requests were at or below that response time.”

## 0:40–1:35 — Experiment 1: load and recovery

**Show:** [load and recovery dashboard](screenshots/load-recovery-grafana.png).

“I held both services at two tasks and turned simulated loss off. I ran five users, increased to 20, and returned to five. At five users, the baseline was 1.65 requests per second and p95 was 2.5 seconds. At 20 users, throughput rose to 3.94 requests per second, but p95 rose to 5.4 seconds. Back at five users, throughput and p95 returned to 1.66 and 2.5 seconds. There were no HTTP failures in these samples. So the service recovered after load decreased, but latency rose substantially at higher concurrency.”

## 1:35–2:25 — Experiment 2: UDP loss

**Show:** [send-loss Locust charts](screenshots/udp-send-5-charts.png).

“Next I held the same five-user workload and task counts, and compared the zero-loss baseline with 5% simulated backend send loss and then 5% receive loss. Median response time stayed at 2.3 seconds, while p95 went from 2.5 to 4.5 seconds in both loss runs. All HTTP requests succeeded in these samples, but the backend logs recorded simulated datagram drops. In the send run, gateway logs also showed missing-chunk retries. This suggests the service handled these losses without observed HTTP failures, but some requests took longer. These were unequal-length, single runs, and 5% was the configured probability.”

## 2:25–3:50 — Experiment 3: autoscaling

**Show:** [ramp task counts](figures/autoscale-ramp-task-counts.png) and [spike ALB graph](screenshots/autoscale-spike-cloudwatch-requests-per-target.png).

“Finally, I restored zero loss and allowed both services to scale between two and four tasks. The gateway targeted 100 ALB requests per target per minute; the backend targeted 60% CPU. I compared a gradual five-to-20-to-50-user ramp with a separate sudden 50-user spike. During the first three minutes at 50 users, the ramp had 627 failures out of 1,345 requests, about 47%. The gateway scaled from two to four tasks; in a later window after all four were healthy, there was one failure in 644 requests. In the spike, the first three-minute sample had 777 failures out of 1,497, about 52%; a later sample after four targets were healthy had zero failures in 492 requests.

“The error reduction coincided with scale-out, but the windows were sequential and don't prove scaling was the sole cause. I manually reduced gateway capacity before the spike, and two targets were still draining at its start, so the trials did not have perfectly identical starting conditions. The backend remained at two tasks in the observed samples.”

## 3:50–4:35 — Takeaway and limitations

“Overall, this workload shows three things: latency rose with load and recovered; simulated packet loss increased tail latency even without HTTP failures; and gateway scaling followed a period of high failure rates at 50 users. The tests used one very small file and one run per condition, so they do not establish general capacity. Locust measured end-to-end HTTP timing, and the Grafana panels displayed Locust client metrics. Response-time percentiles in the failure-heavy scaling samples include failed requests.”

For details, evidence links, exact timestamps, and full limitations, see the [chronological report](REPORT.md).
