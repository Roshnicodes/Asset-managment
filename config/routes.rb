Rails.application.routes.draw do
  resources :vendor_registrations
  resources :vendor_bank_masters
  resources :approval_channels
  resources :firms, except: :show
  resources :product_varieties
  resources :service_types, except: :show
  resources :document_masters, except: :show
  resources :units, except: :show
  resources :stakeholder_categories
  resources :registration_types, except: :show
  resources :office_categories
  resources :blocks
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
# root "states#index"
root to: "dashboard#index"
resources :states
resources :districts
resources :pmus
resources :fcos
resources :tos
resources :themes
resources :products
resources :assets        
resources :allocations
end
