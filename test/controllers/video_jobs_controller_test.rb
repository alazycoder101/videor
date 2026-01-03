require "test_helper"

class VideoJobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @audio_key = "audio/#{SecureRandom.uuid}.mp3"
    @image_key = "image/#{SecureRandom.uuid}.jpg"
  end

  test "renders new form" do
    get new_video_job_path
    assert_response :success
    assert_select "h1", /Create a new video/
  end

  test "creates job and enqueues processor" do
    assert_enqueued_with(job: VideoJobProcessorJob) do
      assert_difference("VideoJob.count", 1) do
        post video_jobs_path, params: { video_job: { audio_key: @audio_key, image_key: @image_key } }
      end
    end

    job = VideoJob.order(:created_at).last
    assert_redirected_to video_job_path(job)
    assert job.client_id.present?
  end

  test "re-renders form when params invalid" do
    assert_no_enqueued_jobs only: VideoJobProcessorJob do
      post video_jobs_path, params: { video_job: { audio_key: "", image_key: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "div", /issue/i
  end

  test "requires ownership for show" do
    job = video_jobs(:one)
    job.update!(client_id: "someone-else")

    get video_job_path(job)
    assert_response :not_found
  end

  test "status action renders partial html" do
    job = create_job_for_current_client

    get status_video_job_path(job)
    assert_response :success
    assert_includes @response.body, "Queued"
  end

  test "download redirects to allowed storage host" do
    job = create_job_for_current_client
    job.update!(status: :finished, output_key: "outputs/test.mp4")

    stubbed_client = Struct.new(:url) do
      def presign_download(_key)
        url
      end
    end.new("https://download.example.test/file.mp4")

    with_stubbed_storage_client(stubbed_client) do
      ENV["STORAGE_HOST_ALLOWLIST"] = "download.example.test"
      get download_video_job_path(job)
      assert_redirected_to stubbed_client.url
    ensure
      ENV.delete("STORAGE_HOST_ALLOWLIST")
    end
  end

  test "download blocks unexpected storage host" do
    job = create_job_for_current_client
    job.update!(status: :finished, output_key: "outputs/test.mp4")

    stubbed_client = Struct.new(:url) do
      def presign_download(_key)
        url
      end
    end.new("https://evil.example/file.mp4")

    with_stubbed_storage_client(stubbed_client) do
      ENV["STORAGE_HOST_ALLOWLIST"] = "download.example.test"
      get download_video_job_path(job)
      assert_redirected_to video_job_path(job)
      follow_redirect!
      assert_match "Download host is not trusted", @response.body
    ensure
      ENV.delete("STORAGE_HOST_ALLOWLIST")
    end
  end

  private

  def create_job_for_current_client
    post video_jobs_path, params: { video_job: { audio_key: @audio_key, image_key: @image_key } }
    VideoJob.order(:created_at).last
  end
end
