Rails.application.routes.draw do
  # Local email inbox (development only): browse sent mail at /letter_opener.
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Registration: email-only by default, with an optional passkey
  get "signup", to: "registrations#new"
  post "signup", to: "registrations#create"
  post "signup/options", to: "registrations#options", as: :signup_options
  post "signup/passkey", to: "registrations#create_passkey", as: :signup_passkey

  # Passkey (WebAuthn) sign in
  get "login", to: "sessions#new"
  post "login/options", to: "sessions#options", as: :login_options
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Passwordless email sign-in (also the domain-change / lost-passkey bridge)
  post "sign-in/email", to: "email_sign_ins#create", as: :email_sign_in_request
  get "sign-in/email/:token", to: "email_sign_ins#show", as: :email_sign_in

  # Email verification (prove control of the address)
  post "verify-email", to: "email_verifications#create", as: :email_verification_request
  get "verify-email/:token", to: "email_verifications#show", as: :email_verification

  get "search", to: "search#show", as: :search

  resources :projects do
    member do
      get :prioritize, to: "comparisons#new"
      get :priorities, to: "priorities#index"
    end
    resources :items, except: :edit do
      member do
        patch :move
        patch :review
        delete :review, action: :unreview, as: nil
      end
      resources :comments, only: %i[create update]
      resources :links, only: %i[create destroy]
    end
    resources :comparisons, only: %i[create destroy]
  end

  namespace :settings do
    resource :account, only: %i[edit update], controller: "account"
    resource :appearance, only: %i[edit update], controller: "appearance"
    resource :admin, only: %i[edit update], controller: "admin" do
      post "failed_emails/:failed_execution_id/retry", action: :retry_email, as: :retry_failed_email
      delete "failed_emails/:failed_execution_id", action: :discard_email, as: :failed_email
    end
    resources :api_keys, only: %i[index create destroy]
    resources :statuses, only: %i[index create update destroy] do
      patch :move, on: :member
    end
    resources :item_types, only: %i[index create update destroy] do
      patch :move, on: :member
    end
    resources :credentials, only: %i[index create destroy] do
      post :options, on: :collection
    end
  end

  namespace :api do
    namespace :v1 do
      resources :projects, only: %i[index show create update destroy] do
        resources :items, only: %i[index create]
      end
      resources :items, only: %i[index show update destroy] do
        member { post :advance }
        resources :comments, only: %i[index create]
        resources :links, only: :create
      end
      # Flat update path so the CLI can address a comment by its id alone.
      resources :comments, only: :update
      resources :links, only: :destroy
      resources :statuses, only: %i[index create update destroy]
      resources :tags, only: :index
    end
  end

  get "up", to: "rails/health#show", as: :rails_health_check

  # PWA files rendered from app/views/pwa/*. Rails::PwaController bypasses the
  # app's login filters, so the browser can fetch these without a session.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "projects#index"
end
