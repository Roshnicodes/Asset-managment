Rails.application.routes.draw do
  get "favicon.ico", to: redirect("/favicon.svg")
  get "q", to: "quotation_vendor_qrs#show"
  get "q/:token", to: "quotation_vendor_qrs#show", as: :short_quotation_vendor_qr
  get "xyz", to: "quotation_vendor_qrs#approved_link"
  get "xyz/:encoded_reference", to: "quotation_vendor_qrs#approved_link", as: :approved_quotation_vendor_qr
  get "p", to: "purchase_order_vendor_qrs#show"
  get "p/:token", to: "purchase_order_vendor_qrs#show", as: :short_purchase_order_vendor_qr
  get "gr/:token", to: "goods_receive_vendor_qrs#show", as: :short_goods_receive_vendor_qr
  get "r", to: redirect("/vr"), as: :short_public_vendor_registration
  get "vr", to: "vendor_registration_invitations#public_start", as: :start_vendor_registration_invitation
  post "vr", to: "vendor_registration_invitations#public_lookup", as: :lookup_vendor_registration_invitation
  get "vr/:token", to: "vendor_registration_invitations#public_show", as: :public_vendor_registration_invitation
  post "vr/:token/send-otp", to: "vendor_registration_invitations#send_otp", as: :send_vendor_registration_invitation_otp
  post "vr/:token/verify-otp", to: "vendor_registration_invitations#verify_otp", as: :verify_vendor_registration_invitation_otp
  post "vr/:token/register", to: "vendor_registration_invitations#register", as: :register_vendor_registration_invitation
  get "quotation-vendor-qr/:token", to: "quotation_vendor_qrs#show", as: :quotation_vendor_qr
  get "quotation-vendor-qr/:token/print", to: "quotation_vendor_qrs#print", as: :print_quotation_vendor_qr
  post "quotation-vendor-qr/:token/send-otp", to: "quotation_vendor_qrs#send_otp", as: :send_quotation_vendor_qr_otp
  post "quotation-vendor-qr/:token/verify-otp", to: "quotation_vendor_qrs#verify_otp", as: :verify_quotation_vendor_qr_otp
  get "purchase-order-vendor/:token", to: "purchase_order_vendor_qrs#show", as: :purchase_order_vendor_qr
  post "purchase-order-vendor/:token/send-otp", to: "purchase_order_vendor_qrs#send_otp", as: :send_purchase_order_vendor_qr_otp
  post "purchase-order-vendor/:token/verify-otp", to: "purchase_order_vendor_qrs#verify_otp", as: :verify_purchase_order_vendor_qr_otp
  patch "purchase-order-vendor/:token", to: "purchase_order_vendor_qrs#update"
  get "goods-receive-vendor/:token", to: "goods_receive_vendor_qrs#show", as: :goods_receive_vendor_qr
  post "goods-receive-vendor/:token/send-otp", to: "goods_receive_vendor_qrs#send_otp", as: :send_goods_receive_vendor_qr_otp
  post "goods-receive-vendor/:token/verify-otp", to: "goods_receive_vendor_qrs#verify_otp", as: :verify_goods_receive_vendor_qr_otp
  patch "goods-receive-vendor/:token", to: "goods_receive_vendor_qrs#update"
  resources :notifications, only: [:index]
  resources :menu_permissions, only: [:index, :create]
  resources :quotation_proposals do
    collection do
      get :list
      get :payment_advice
      patch :update_payment_advice, path: "payment_advice"
      post :send_for_approval
    end
    member do
      post :send_for_approval
      patch :approve_committee
      patch :return_committee
      patch :assign_payment_references
      post :send_to_vendors
      get :purchase_order
      post :send_purchase_order
      get :goods_receive
      patch :update_goods_receive
      patch "invoice_requests/:invoice_request_id/review", action: :review_invoice_request, as: :review_invoice_request
      get "invoice_requests/:invoice_request_id/assets/new", action: :new_invoice_request_assets, as: :new_invoice_request_assets
      post "invoice_requests/:invoice_request_id/assets", action: :create_invoice_request_assets, as: :create_invoice_request_assets
      patch "vendors/:proposal_vendor_id/purchase_order_reply", action: :update_purchase_order_reply, as: :update_purchase_order_reply
      patch :score_vendors
      patch "vendors/:proposal_vendor_id/score", action: :score_vendor, as: :score_vendor
      patch "vendors/:proposal_vendor_id/select", action: :select_vendor, as: :select_vendor
    end
  end
  patch "quotation-vendor-qr/:token", to: "quotation_vendor_qrs#update"
  resources :approval_requests, only: [:index] do
    member do
      patch :approve
      patch :return_request
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
  resources :vendor_registration_invitations, only: %i[new create show] do
    member do
      post :resend
    end
  end
  resources :employee_masters do
    member do
      post :reset_login_password
    end

    collection do
      get :export
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
  resources :office_category_masters
  resources :office_categories
  resources :blocks
  get "users", to: redirect("/users/sign_in")
  devise_for :users, controllers: { passwords: 'users/passwords', registrations: 'users/registrations', sessions: 'users/sessions' }
  authenticated :user do
    root to: "dashboard#index", as: :authenticated_root
  end

  unauthenticated do
    root to: redirect("/users/sign_in")
  end
  resources :states
  resources :districts
  resources :pmus
  resources :fcos
  resources :tos
  resources :themes
  resources :vendor_selection_criteria, except: :show
  resources :products
  resources :asset_insurances, only: [:index] do
    collection do
      get :overview
      patch :update_all
    end
  end
  resources :assets do
    member do
      get :remove
    end
  end
  resources :allocations
  resource :profile, only: [:show, :edit, :update]
end
