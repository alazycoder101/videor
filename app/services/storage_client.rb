class StorageClient
  class Error < StandardError; end

  DEFAULT_MAX_SIZE = 150.megabytes

  attr_reader :bucket, :client

  def initialize(bucket: ENV.fetch("VIDEO_JOBS_BUCKET", "video-jobs"), region: ENV["AWS_REGION"], endpoint: ENV["S3_ENDPOINT"])
    @bucket = bucket
    client_options = { region: region.presence || "us-east-1" }
    if endpoint.present?
      client_options[:endpoint] = endpoint
      client_options[:force_path_style] = true
    end
    @client = Aws::S3::Client.new(client_options)
  end

  def generate_object_key(purpose:, filename:)
    safe_name = filename.to_s
    extension = File.extname(safe_name)
    sanitized_name = File.basename(safe_name, extension).parameterize.presence || purpose
    File.join(purpose, SecureRandom.uuid, "#{sanitized_name}#{extension.presence || default_extension(purpose)}")
  end

  def presign_upload(key:, content_type:, byte_size: DEFAULT_MAX_SIZE, expires_in: 10.minutes)
    content_type = content_type.presence || "application/octet-stream"
    byte_size = DEFAULT_MAX_SIZE if byte_size.to_i <= 0

    post = Aws::S3::PresignedPost.new(
      client:,
      bucket:,
      key: key,
      signature_expiration: expires_in.from_now,
      conditions: [
        ["content-length-range", 0, byte_size],
        ["eq", "$Content-Type", content_type]
      ]
    )

    { url: post.url, fields: post.fields }
  rescue Aws::Errors::ServiceError => e
    raise Error, e.message
  end

  def presign_download(key, expires_in: 15.minutes)
    presigner.presigned_url(:get_object, bucket:, key:, expires_in: expires_in.to_i)
  rescue Aws::Errors::ServiceError => e
    raise Error, e.message
  end

  def download_to_tempfile(key)
    tempfile = Tempfile.new(["video-job", File.extname(key)])
    tempfile.binmode
    client.get_object(bucket:, key:) do |chunk|
      tempfile.write(chunk)
    end
    tempfile.rewind
    tempfile
  rescue Aws::Errors::ServiceError => e
    tempfile&.close!
    raise Error, e.message
  end

  def upload_file(path, key: nil, content_type: "video/mp4")
    key ||= default_output_key(File.basename(path))
    File.open(path, "rb") do |file|
      client.put_object(bucket:, key:, body: file, content_type:)
    end
    key
  rescue Aws::Errors::ServiceError => e
    raise Error, e.message
  end

  private

  def default_extension(purpose)
    case purpose
    when "audio" then ".mp3"
    when "image" then ".jpg"
    else ".bin"
    end
  end

  def default_output_key(filename)
    File.join("outputs", filename)
  end

  def presigner
    @presigner ||= Aws::S3::Presigner.new(client:)
  end
end
