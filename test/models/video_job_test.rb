require "test_helper"

class VideoJobTest < ActiveSupport::TestCase
  test "requires client and upload keys" do
    job = VideoJob.new

    assert_predicate job, :invalid?
    assert_includes job.errors[:client_id], "can't be blank"
    assert_includes job.errors[:audio_key], "can't be blank"
    assert_includes job.errors[:image_key], "can't be blank"
  end

  test "ready_for_download requires finished status and output key" do
    job = video_jobs(:finished)
    assert job.ready_for_download?

    job.output_key = nil
    assert_not job.ready_for_download?

    job.status = :processing
    job.output_key = "outputs/new.mp4"
    assert_not job.ready_for_download?
  end

  test "owned_by scope filters by cookie client" do
    mine = VideoJob.create!(client_id: "cookie-123", audio_key: "audio/a.mp3", image_key: "image/a.jpg")
    VideoJob.create!(client_id: "cookie-456", audio_key: "audio/b.mp3", image_key: "image/b.jpg")

    assert_equal [ mine ], VideoJob.owned_by("cookie-123")
  end
end
