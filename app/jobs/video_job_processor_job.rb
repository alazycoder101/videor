class VideoJobProcessorJob < ApplicationJob
  queue_as :default

  def perform(video_job_id)
    video_job = VideoJob.find(video_job_id)
    storage = StorageClient.new

    video_job.processing!

    audio_file = storage.download_to_tempfile(video_job.audio_key)
    image_file = storage.download_to_tempfile(video_job.image_key)
    output_file = Tempfile.new(["video-job-output", ".mp4"])
    output_file.binmode

    run_ffmpeg(audio_file.path, image_file.path, output_file.path)
    output_file.rewind

    output_key = storage.upload_file(
      output_file.path,
      key: build_output_key(video_job),
      content_type: "video/mp4"
    )

    video_job.update!(status: :finished, output_key:, error_message: nil)
  rescue StandardError => e
    video_job.update!(status: :failed, error_message: e.message.truncate(255)) if video_job&.persisted?
    raise
  ensure
    [audio_file, image_file, output_file].compact.each do |file|
      file.close!
    rescue StandardError
      # no-op
    end
  end

  private

  def run_ffmpeg(audio_path, image_path, output_path)
    command = [
      "ffmpeg",
      "-y",
      "-loop", "1",
      "-i", image_path,
      "-i", audio_path,
      "-c:v", "libx264",
      "-tune", "stillimage",
      "-c:a", "aac",
      "-shortest",
      output_path
    ]

    system(*command, out: File::NULL, err: File::NULL) || raise("ffmpeg failed to generate the video")
  end

  def build_output_key(video_job)
    timestamp = Time.current.utc.strftime("%Y%m%d%H%M%S")
    "outputs/#{video_job.id}-#{timestamp}.mp4"
  end
end
