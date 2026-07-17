Rails.application.routes.draw do
  # Passkey (WebAuthn) registration
  get "signup", to: "registrations#new"
  post "signup/options", to: "registrations#options", as: :signup_options
  post "signup", to: "registrations#create"

  # Passkey (WebAuthn) sign in
  get "login", to: "sessions#new"
  post "login/options", to: "sessions#options", as: :login_options
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  resources :projects do
    resources :items
  end

  get "up", to: "rails/health#show", as: :rails_health_check

  root "projects#index"
end
