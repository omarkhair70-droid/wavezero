# WaveZero direct audio retry

WaveZero keeps direct downloadable audio on the existing Android DownloadManager path.

When a recent direct-audio task is failed, cancelled, or no longer present in DownloadManager history, Downloads exposes Retry. Retry re-enqueues the original direct audio URL, persists the new DownloadManager ID into the same Music Inbox entry, and resumes the existing polling/UI flow. It does not create a second downloader or a second media library.

Downloads now also shows transferred bytes when Android reports them, which makes slow transfers easier to distinguish from a stalled UI.
