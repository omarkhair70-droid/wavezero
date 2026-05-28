/// Platform-normalized network state.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetworkScore {
    pub network_type: NetworkType,
    pub bandwidth_kbps: u32,
    pub latency_ms: u32,
    pub metered: bool,
}

impl NetworkScore {
    pub fn new(
        network_type: NetworkType,
        bandwidth_kbps: u32,
        latency_ms: u32,
        metered: bool,
    ) -> Self {
        Self {
            network_type,
            bandwidth_kbps,
            latency_ms,
            metered,
        }
    }

    pub fn supports_audio_prefetch(&self, bitrate_kbps: u32) -> bool {
        matches!(
            self.network_type,
            NetworkType::Wifi | NetworkType::Cellular5g | NetworkType::Ethernet
        ) && !self.metered
            && self.bandwidth_kbps >= bitrate_kbps.saturating_mul(3)
            && self.latency_ms <= 250
    }

    pub fn supports_manifest_prefetch(&self) -> bool {
        !matches!(
            self.network_type,
            NetworkType::Offline | NetworkType::Unknown
        ) && self.bandwidth_kbps >= 128
            && self.latency_ms <= 500
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NetworkType {
    Offline,
    Unknown,
    Wifi,
    Ethernet,
    Cellular4g,
    Cellular5g,
}
