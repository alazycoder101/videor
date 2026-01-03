class VideoJobsController < ApplicationController
  before_action :set_video_job, only: %i[show status download]
  before_action :authorize_video_job!, only: %i[show status download]

  def index
    @video_jobs = VideoJob.owned_by(current_client_id).order(created_at: :desc)
  end

  def new
    @video_job = VideoJob.new
  end

  def create
    @video_job = VideoJob.new(video_job_params.merge(client_id: current_client_id))

    if @video_job.save
      VideoJobProcessorJob.perform_later(@video_job.id)
      redirect_to @video_job, notice: "Your video is queued for processing."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show; end

  def status
    render partial: "video_jobs/status", locals: { video_job: @video_job }
  end

  def download
    unless @video_job.ready_for_download?
      redirect_to @video_job, alert: "Hold tight—processing is still running." and return
    end

    redirect_to storage_client.presign_download(@video_job.output_key), allow_other_host: true
  rescue StorageClient::Error => e
    redirect_to @video_job, alert: e.message
  end

  private

  def set_video_job
    @video_job = VideoJob.find(params[:id])
  end

  def authorize_video_job!
    head :not_found unless @video_job.client_id == current_client_id
  end

  def video_job_params
    params.require(:video_job).permit(:audio_key, :image_key)
  end
end
