Rails.application.routes.draw do
  root "video_jobs#new"

  resources :video_jobs, only: %i[index new create show] do
    member do
      get :status
      get :download
    end
  end

  namespace :uploads do
    post :presign, to: "presigns#create"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
