"""Expose the local Locust web API as Prometheus metrics.

These are client-side Locust measurements, not per-task service metrics.
"""

import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

URL = os.environ.get("LOCUST_STATS_URL", "http://host.docker.internal:8089/stats/requests")


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/metrics":
            self.send_error(404)
            return
        lines = ["# HELP locust_up Whether the Locust API was reachable.", "# TYPE locust_up gauge"]
        try:
            with urllib.request.urlopen(URL, timeout=3) as response:
                data = json.load(response)
            lines.append("locust_up 1")
            aggregate = next((row for row in data.get("stats", []) if row.get("name") == "Aggregated"), {})
            stopped = data.get("state") == "stopped"
            fields = {
                "locust_users": data.get("user_count"),
                "locust_current_requests_per_second": 0 if stopped else data.get("current_rps", aggregate.get("current_rps")),
                "locust_current_failures_per_second": 0 if stopped else data.get("current_fail_per_sec", aggregate.get("current_fail_per_sec")),
                "locust_requests_total": aggregate.get("num_requests"),
                "locust_failures_total": aggregate.get("num_failures"),
            }
            for name, value in fields.items():
                if isinstance(value, (int, float)):
                    metric_type = "counter" if name.endswith("_total") else "gauge"
                    lines.extend((f"# TYPE {name} {metric_type}", f"{name} {value}"))
            percentiles = {} if stopped else (data.get("current_response_time_percentiles") or {})
            lines.append("# TYPE locust_current_response_time_milliseconds gauge")
            for quantile in ("0.5", "0.95"):
                value = percentiles.get("response_time_percentile_" + quantile)
                if isinstance(value, (int, float)):
                    lines.append(f'locust_current_response_time_milliseconds{{quantile="{quantile}"}} {value}')
        except (OSError, ValueError, urllib.error.URLError):
            lines.append("locust_up 0")
        body = ("\n".join(lines) + "\n").encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


ThreadingHTTPServer(("0.0.0.0", 9464), MetricsHandler).serve_forever()
