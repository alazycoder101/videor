require "test_helper"

class VideoJobProcessorJobTest < ActiveJob::TestCase
  setup do
    @video_job = VideoJob.create!(client_id: "job-client", audio_key: "audio/source.mp3", image_key: "image/source.jpg")
  end

  test "transitions job to finished and stores output key" do
    fake_storage = FakeStorageClient.new
    job = build_job(storage: fake_storage, runner: ->(*_) { true })

    job.perform(@video_job.id)

    @video_job.reload
    assert_equal "stored-output.mp4", @video_job.output_key
    assert @video_job.finished?
    assert_nil @video_job.error_message
  end

  test "records failure message when ffmpeg raises" do
    fake_storage = FakeStorageClient.new
    job = build_job(storage: fake_storage, runner: ->(*_) { raise "boom" })

    assert_raises RuntimeError do
      job.perform(@video_job.id)
    end

    @video_job.reload
    assert @video_job.failed?
    assert_match "boom", @video_job.error_message
  end

  class FakeStorageClient
    attr_reader :upload_arguments

    def initialize
      @upload_arguments = []
    end

    def download_to_tempfile(key)
      file = Tempfile.new([ "fixture", File.extname(key) ])
      file.binmode
      file.write("test data")
      file.rewind
      file
    end

    def upload_file(path, key:, content_type:)
      @upload_arguments << { path:, key:, content_type: }
      "stored-output.mp4"
    end
  end

  private

  def build_job(storage:, runner:)
    Class.new(VideoJobProcessorJob) do
      def initialize(storage:, runner:)
        @storage = storage
        @runner = runner
      end

      def perform(*)
        super
      end

      private

      def storage_client
        @storage
      end

      def run_ffmpeg(*args)
        @runner.call(*args)
      end
    end.new(storage:, runner:)
  end
end
