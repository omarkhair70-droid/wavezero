use crate::Track;

/// Ordered playback state shared by clients.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct PlaybackQueue {
    tracks: Vec<Track>,
    current_index: Option<usize>,
}

impl PlaybackQueue {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set_queue(&mut self, tracks: Vec<Track>, start_track_id: Option<&str>) {
        self.current_index = if tracks.is_empty() {
            None
        } else if let Some(track_id) = start_track_id {
            tracks
                .iter()
                .position(|track| track.id == track_id)
                .or(Some(0))
        } else {
            Some(0)
        };
        self.tracks = tracks;
    }

    pub fn current_track(&self) -> Option<&Track> {
        self.current_index.and_then(|index| self.tracks.get(index))
    }

    pub fn peek_next_track(&self) -> Option<&Track> {
        self.current_index
            .and_then(|index| self.tracks.get(index.saturating_add(1)))
    }

    pub fn next_track(&mut self) -> Option<&Track> {
        let next_index = self.current_index?.checked_add(1)?;
        if next_index < self.tracks.len() {
            self.current_index = Some(next_index);
            self.current_track()
        } else {
            None
        }
    }

    pub fn previous_track(&mut self) -> Option<&Track> {
        let previous_index = self.current_index?.checked_sub(1)?;
        self.current_index = Some(previous_index);
        self.current_track()
    }

    pub fn move_to_track(&mut self, track_id: &str) -> Option<&Track> {
        let index = self.tracks.iter().position(|track| track.id == track_id)?;
        self.current_index = Some(index);
        self.current_track()
    }

    pub fn tracks(&self) -> &[Track] {
        &self.tracks
    }

    pub fn current_index(&self) -> Option<usize> {
        self.current_index
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{AudioCodec, TrackAsset};

    fn track(id: &str) -> Track {
        Track::new(
            id,
            "artist-1",
            format!("Track {id}"),
            180_000,
            vec![TrackAsset::new(
                format!("asset-{id}"),
                id,
                format!("https://cdn.wavezero.test/{id}/master.m3u8"),
                AudioCodec::AacLc,
                256,
                32,
                true,
            )],
        )
    }

    #[test]
    fn set_queue_defaults_to_first_track() {
        let mut queue = PlaybackQueue::new();
        queue.set_queue(vec![track("a"), track("b")], None);

        assert_eq!(
            queue.current_track().map(|track| track.id.as_str()),
            Some("a")
        );
        assert_eq!(queue.current_index(), Some(0));
    }

    #[test]
    fn navigation_moves_between_tracks_without_wrapping() {
        let mut queue = PlaybackQueue::new();
        queue.set_queue(vec![track("a"), track("b"), track("c")], Some("b"));

        assert_eq!(
            queue.current_track().map(|track| track.id.as_str()),
            Some("b")
        );
        assert_eq!(queue.next_track().map(|track| track.id.as_str()), Some("c"));
        assert!(queue.next_track().is_none());
        assert_eq!(
            queue.previous_track().map(|track| track.id.as_str()),
            Some("b")
        );
        assert_eq!(
            queue.previous_track().map(|track| track.id.as_str()),
            Some("a")
        );
        assert!(queue.previous_track().is_none());
    }

    #[test]
    fn move_to_track_updates_current_track_when_found() {
        let mut queue = PlaybackQueue::new();
        queue.set_queue(vec![track("a"), track("b")], None);

        assert_eq!(
            queue.move_to_track("b").map(|track| track.id.as_str()),
            Some("b")
        );
        assert_eq!(queue.current_index(), Some(1));
        assert!(queue.move_to_track("missing").is_none());
        assert_eq!(queue.current_index(), Some(1));
    }
}
