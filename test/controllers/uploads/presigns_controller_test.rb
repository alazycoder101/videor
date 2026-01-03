require "test_helper"

class Uploads::PresignsControllerTest < ActionDispatch::IntegrationTest
  test "returns signature payload for supported purpose" do
    fake_client = FakeStorageClient.new

    with_stubbed_storage_client(fake_client) do
      post uploads_presign_path, params: {
        upload: {
          filename: "track.mp3",
          content_type: "audio/mpeg",
          byte_size: 1024,
          purpose: "audio"
        }
      }, as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal fake_client.generated_key, json["key"]
    assert_equal "audio/mpeg", fake_client.presign_arguments[:content_type]
  end

  test "rejects unknown purpose" do
    post uploads_presign_path, params: { upload: { filename: "file", content_type: "text/plain", byte_size: 1, purpose: "other" } }, as: :json

    assert_response :unprocessable_entity
    assert_match "Unknown upload type", @response.body
  end

  class FakeStorageClient
    attr_reader :presign_arguments, :generated_key

    def initialize
      @generated_key = "audio/#{SecureRandom.uuid}/track.mp3"
    end

    def generate_object_key(purpose:, filename:)
      @generate_arguments = { purpose:, filename: }
      @generated_key
    end

    def presign_upload(**arguments)
      @presign_arguments = arguments
      {
        url: "https://example-bucket.test/uploads",
        fields: {
          key: @generated_key,
          policy: "encoded"
        }
      }
    end
  end
end
