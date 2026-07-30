class DriveGuideGenerator
  GUIDE = "安全運転で出発しましょう。周囲をよく確認してください。".freeze
  MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5.6-luna")

  class GenerationError < StandardError; end

  def self.call(latitude:, longitude:, location: nil, landmarks: [])
    new.call(latitude:, longitude:, location:, landmarks:)
  end

  def initialize(client: nil, api_key: ENV["OPENAI_API_KEY"], model: MODEL)
    @client = client
    @api_key = api_key
    @model = model
  end

  def call(latitude:, longitude:, location: nil, landmarks: [])
    return GUIDE if @api_key.blank?

    response = client.responses.create(
      model: @model,
      instructions: "あなたは日本語の観光バスガイドです。運転中の乗客へ、40〜70文字程度の短い一文を返してください。" \
        "地点名と近隣スポットとして与えられた情報だけを事実として使い、言及するスポットは最大1つにしてください。" \
        "歴史、営業時間、交通状況、道路規制、混雑などは推測して断定しないでください。" \
        "近隣スポットがなければ、安全確認を促す短い案内にしてください。",
      input: input_for(latitude:, longitude:, location:, landmarks:)
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

  def input_for(latitude:, longitude:, location:, landmarks:)
    context = []
    context << "現在地の周辺: #{location}" if location.present?
    context << "近隣の実在スポット: #{landmarks.join("、")}" if landmarks.any?
    context << "おおよその現在地: 緯度 #{latitude.round(3)}, 経度 #{longitude.round(3)}" if context.empty?
    context.join("\n")
  end
end
