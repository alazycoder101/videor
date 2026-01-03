class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :ensure_client_identity

  helper_method :current_client_id
  helper_method :storage_client

  private

  def ensure_client_identity
    return if current_client_id.present?

    cookies.permanent.signed[:client_id] = {
      value: SecureRandom.uuid,
      httponly: true
    }
  end

  def current_client_id
    cookies.signed[:client_id]
  end

  def storage_client
    @storage_client ||= StorageClient.new
  end
end
