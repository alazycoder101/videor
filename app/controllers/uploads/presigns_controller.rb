module Uploads
  class PresignsController < ApplicationController
    protect_from_forgery with: :exception

    before_action :assert_known_purpose!

    def create
      upload = presign_params

      content_type = upload[:content_type].presence || "application/octet-stream"
      byte_size = upload[:byte_size].to_i
      byte_size = StorageClient::DEFAULT_MAX_SIZE if byte_size <= 0

      key = storage_client.generate_object_key(purpose: upload[:purpose], filename: upload[:filename])
      signature = storage_client.presign_upload(
        key:,
        content_type:,
        byte_size:
      )

      render json: signature.merge(key:)
    rescue StorageClient::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def presign_params
      params.require(:upload).permit(:filename, :content_type, :purpose, :byte_size)
    end

    def assert_known_purpose!
      return if %w[audio image].include?(params.dig(:upload, :purpose))

      render json: { error: "Unknown upload type" }, status: :unprocessable_entity
    end
  end
end
