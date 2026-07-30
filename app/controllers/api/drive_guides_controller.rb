module Api
  class DriveGuidesController < ApplicationController
    def create
      unless Rails.env.development? || DriveGuideRequestLimiter.allow?(request.remote_ip)
        render json: { error: "ガイドの取得が集中しています。少し時間を置いてからもう一度お試しください。" }, status: :too_many_requests
        return
      end

      latitude = coordinate!(:latitude, -90.0..90.0)
      longitude = coordinate!(:longitude, -180.0..180.0)
      location = LocationLabelResolver.call(latitude:, longitude:)
      landmarks = NearbyLandmarkResolver.call(latitude:, longitude:)
      history = WikipediaSummaryResolver.call(title: landmarks.find(&:wikipedia_title)&.wikipedia_title)

      guide = DriveGuideGenerator.call(latitude:, longitude:, location:, landmarks: landmarks.map(&:name), history:)

      render json: {
        guide: guide.display_text,
        speech_text: guide.speech_text,
        location:
      }
    rescue DriveGuideGenerator::GenerationError
      render json: { error: "ガイドを生成できませんでした。しばらくしてからもう一度お試しください。" }, status: :service_unavailable
    rescue ActionController::ParameterMissing, ArgumentError
      render json: { error: "位置情報を正しく受信できませんでした。" }, status: :unprocessable_entity
    end

    private

    def coordinate!(name, range)
      coordinate = Float(params.require(name))
      raise ArgumentError unless range.cover?(coordinate)

      coordinate
    end
  end
end
