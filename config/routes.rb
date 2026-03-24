Rails.application.routes.draw do
  resources :notifications, only: [:index]
  resources :menu_permissions, only: [:index, :create]
  resources :approval_requests, only: [:index] do
    member do
      patch :approve
      patch :reject
    end
  end
  resources :vendor_registrations do
    member do
      post :send_for_approval
    end

    collection do
      get :list
      post :send_for_approval
    end
  end
  resources :employee_masters do
    collection do
      post :import
      post :sync_logins
    end
  end
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
  devise_for :users, controllers: { passwords: 'users/passwords' }
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
  resource :profile, only: [:show, :edit, :update]
end
