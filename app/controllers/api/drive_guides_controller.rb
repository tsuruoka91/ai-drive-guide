module Api
  class DriveGuidesController < ApplicationController
    def create
      latitude = coordinate!(:latitude, -90.0..90.0)
      longitude = coordinate!(:longitude, -180.0..180.0)
      location = LocationLabelResolver.call(latitude:, longitude:)
      landmarks = NearbyLandmarkResolver.call(latitude:, longitude:)

      render json: {
        guide: DriveGuideGenerator.call(latitude:, longitude:, location:, landmarks:),
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
