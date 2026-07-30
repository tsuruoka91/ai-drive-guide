class DriveGuideGenerator
  GUIDE = "安全運転で出発しましょう。周囲をよく確認してください。".freeze

  def self.call(latitude:, longitude:)
    # Coordinates are intentionally not persisted in the MVP.
    GUIDE
  end
end
