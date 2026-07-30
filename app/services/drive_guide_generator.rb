class DriveGuideGenerator
  GUIDE = "安全運転で出発しましょう。周囲をよく確認してください。".freeze
  MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5.6-luna")

  class GenerationError < StandardError; end

  def self.call(latitude:, longitude:, location: nil, landmarks: [], history: nil)
    new.call(latitude:, longitude:, location:, landmarks:, history:)
  end

  def initialize(client: nil, api_key: ENV["OPENAI_API_KEY"], model: MODEL)
    @client = client
    @api_key = api_key
    @model = model
  end

  def call(latitude:, longitude:, location: nil, landmarks: [], history: nil)
    return GUIDE if @api_key.blank?

    response = client.responses.create(
      model: @model,
      instructions: "あなたは日本語の観光バスガイドです。乗客へ、聞きやすい案内を返してください。",
      input: input_for(latitude:, longitude:, location:, landmarks:, history:)
    )
    guide = response.output_text.to_s.strip

    raise GenerationError, "empty response" if guide.empty?

    guide
  rescue GenerationError
    raise
  rescue StandardError => error
    raise GenerationError, error.message
  end

  private

  def client
    @client ||= OpenAI::Client.new
  end

  def input_for(latitude:, longitude:, location:, landmarks:, history:)
    context = []
    context << "現在地の周辺: #{location}" if location.present?
    context << "近隣の実在スポット: #{landmarks.join("、")}" if landmarks.any?
    context << "確認済みの歴史・概要: #{history}" if history.present?
    context << "おおよその現在地: 緯度 #{latitude.round(3)}, 経度 #{longitude.round(3)}" if context.empty?
    context.join("\n")
  end
end
