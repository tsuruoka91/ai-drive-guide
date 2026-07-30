require "json"

class DriveGuideGenerator
  Guide = Data.define(:display_text, :speech_text)

  GUIDE = Guide.new(
    display_text: "安全運転で出発しましょう。周囲をよく確認してください。",
    speech_text: "あんぜんうんてんで しゅっぱつしましょう。しゅういを よく かくにんしてください。"
  ).freeze
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
      instructions: instructions,
      input: input_for(latitude:, longitude:, location:, landmarks:, history:),
      text: { format: response_format }
    )
    guide_from(response.output_text)
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

  def instructions
    <<~INSTRUCTIONS.squish
      あなたは日本語の観光バスガイドです。乗客向けに、現在地周辺の聞きやすい案内を作成してください。
      display_text は画面表示用の通常の日本語表記です。地名・人名・施設名と一般的な語には漢字を使い、ひらがなだけの文章にはしないでください。
      speech_text は display_text と同じ内容の読み上げ専用文です。こちらだけは漢字を一切使わず、地名・人名・施設名を含めて正しい読みのひらがなまたはカタカナにしてください。
      読みやすい位置で句読点と空白を使えます。
    INSTRUCTIONS
  end

  def response_format
    {
      type: "json_schema",
      name: "drive_guide",
      strict: true,
      schema: {
        type: "object",
        properties: {
          display_text: { type: "string" },
          speech_text: { type: "string" }
        },
        required: %w[display_text speech_text],
        additionalProperties: false
      }
    }
  end

  def guide_from(output_text)
    payload = JSON.parse(output_text.to_s)
    display_text = payload.fetch("display_text").to_s.strip
    speech_text = payload.fetch("speech_text").to_s.strip

    raise GenerationError, "empty response" if display_text.empty? || speech_text.empty?
    raise GenerationError, "display text contains no kanji" unless display_text.match?(/\p{Han}/)
    raise GenerationError, "speech text contains kanji" if speech_text.match?(/\p{Han}/)

    Guide.new(display_text:, speech_text:)
  rescue JSON::ParserError, KeyError
    raise GenerationError, "invalid response format"
  end
end
