class TestTrack {
  const TestTrack({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;
}

const waveZeroTestTrack = TestTrack(
  title: 'Apple BipBop HLS Demo',
  url:
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear0/prog_index.m3u8',
);
