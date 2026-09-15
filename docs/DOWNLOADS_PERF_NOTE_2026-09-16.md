# Direct audio download performance note

Daily-driver feedback: a web-triggered audio download can feel slower than expected.

Current transfer bytes are owned by Android DownloadManager, not a WaveZero socket implementation. Downloads now surfaces transferred bytes alongside percentage when Android reports total size, so the next device test can distinguish source/network throughput from UI/polling delay.

Do not replace DownloadManager or add a parallel downloader based on this observation alone. Re-test with multiple direct audio hosts after Retry ships, then optimize only the measured bottleneck.
