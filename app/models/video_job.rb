class VideoJob < ApplicationRecord
  enum status: {
    queued: 0,
    processing: 1,
    finished: 2,
    failed: 3
  }

  validates :client_id, presence: true
  validates :audio_key, presence: true
  validates :image_key, presence: true

  scope :owned_by, ->(client_id) { where(client_id:) }

  after_commit :broadcast_status_update, on: %i[create update]

  def ready_for_download?
    finished? && output_key.present?
  end

  private

  def broadcast_status_update
    broadcast_replace_to(
      self,
      target: ActionView::RecordIdentifier.dom_id(self, :status),
      partial: "video_jobs/status",
      locals: { video_job: self }
    )
  end
end
