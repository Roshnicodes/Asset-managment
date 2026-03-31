Rails.application.routes.draw do
  get "quotation-vendor-qr/:token", to: "quotation_vendor_qrs#show", as: :quotation_vendor_qr
  post "quotation-vendor-qr/:token/send-otp", to: "quotation_vendor_qrs#send_otp", as: :send_quotation_vendor_qr_otp
  post "quotation-vendor-qr/:token/verify-otp", to: "quotation_vendor_qrs#verify_otp", as: :verify_quotation_vendor_qr_otp
  resources :notifications, only: [:index]
  resources :menu_permissions, only: [:index, :create]
  resources :quotation_proposals do
    collection do
      get :list
      post :send_for_approval
    end
    member do
      post :send_for_approval
      patch :approve_committee
      patch :return_committee
      post :send_to_vendors
      patch "vendors/:proposal_vendor_id/score", action: :score_vendor, as: :score_vendor
      patch "vendors/:proposal_vendor_id/select", action: :select_vendor, as: :select_vendor
    end
  end
  patch "quotation-vendor-qr/:token", to: "quotation_vendor_qrs#update"
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
