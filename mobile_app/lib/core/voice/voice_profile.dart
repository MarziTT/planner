class ButlerVoiceProfile {
  const ButlerVoiceProfile({
    this.rate = 0.42,
    this.pitch = 0.86,
    this.maxCharacters = 150,
  });

  /// Calm, restrained, concise defaults with a slightly mechanical cadence.
  /// This is an original speaking profile and does not imitate a copyrighted
  /// character or actor.
  final double rate;
  final double pitch;
  final int maxCharacters;
}
