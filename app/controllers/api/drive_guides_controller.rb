module Api
  class DriveGuidesController < ApplicationController
    def create
      latitude = coordinate!(:latitude, -90.0..90.0)
      longitude = coordinate!(:longitude, -180.0..180.0)

      render json: { guide: DriveGuideGenerator.call(latitude:, longitude:) }
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
