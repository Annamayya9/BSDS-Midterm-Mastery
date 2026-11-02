"""Locust workload for the file-transfer gateway.

Set FILE_NAMES to a comma-separated list of uploaded names. The workload issues
GET /files?name=... requests with no deliberate wait, so it is closed-loop.
"""

import os
import random

from locust import HttpUser, constant, task


def configured_files():
    names = [name.strip() for name in os.getenv("FILE_NAMES", "").split(",")]
    names = [name for name in names if name]
    if not names:
        raise RuntimeError("Set FILE_NAMES to one or more names uploaded under the S3 prefix")
    return names


FILES = configured_files()


class FileDownloadUser(HttpUser):
    """Repeatedly fetch a randomly selected file from the fixed test set."""

    # One second of think time by default keeps the first experiment modest; set
    # WAIT_SECONDS=0 for an unpaced stress stage.
    wait_time = constant(float(os.getenv("WAIT_SECONDS", "1")))

    @task
    def download_file(self):
        name = random.choice(FILES)
        with self.client.get(
            "/files",
            params={"name": name},
            name="GET /files",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(f"HTTP {response.status_code} for file {name}")
