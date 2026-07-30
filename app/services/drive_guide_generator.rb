class DriveGuideGenerator
  GUIDE = "安全運転で出発しましょう。周囲をよく確認してください。".freeze
  MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5.6-luna")

  class GenerationError < StandardError; end

  def self.call(latitude:, longitude:)
    new.call(latitude:, longitude:)
  end

  def initialize(client: nil, api_key: ENV["OPENAI_API_KEY"], model: MODEL)
    @client = client
    @api_key = api_key
    @model = model
  end

  def call(latitude:, longitude:)
    return GUIDE if @api_key.blank?

    response = client.responses.create(
      model: @model,
      instructions: "あなたは安全運転を支援する日本語のドライブガイドです。" \
        "指定地点の周辺を走行中の人へ、20〜40文字程度の短い一文を返してください。" \
        "道路状況、交通規制、店舗などを推測して断定しないでください。" \
        "安全確認を促す内容にしてください。",
      input: "おおよその現在地: 緯度 #{latitude.round(3)}, 経度 #{longitude.round(3)}"
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
end
