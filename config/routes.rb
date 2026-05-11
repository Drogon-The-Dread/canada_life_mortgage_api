Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :mortgage_applications, only: %i[create show] do
        get :assessment, on: :member
      end
    end
  end

  mount Rswag::Ui::Engine  => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  root to: redirect("/api-docs")
end
