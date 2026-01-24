require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do

  # ahoy
  # https://github.com/ankane/ahoy/blob/master/config/routes.rb
  # TODO: change url

  resources :coupons
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # /
  root controller: :tenders, action: :home

  resources :queries
  get '/redeem', controller: :queries, action: :redeem, as: :redeem
  post '/redeem', controller: :queries, action: :redeem_coupon, as: :redeem_coupon

  get '/dashboard/bookmarks', to: 'tenders#bookmarks', as: :bookmarks

  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    # sessions: 'users/sessions'
    # confirmation: 'users/confirmations'
    registrations: 'users/registrations'
  }
  authenticate :admin_user, lambda { |u| u.present? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  # devise_for :users
  # nav
  get '/about', controller: :home, action: :about
  # get '/login', controller: :home, action: :login
  # get '/signup', controller: :home, action: :signup
  get '/services', controller: :home, action: :services
  get '/coming-soon', controller: :home, action: :coming_soon
  get '/get-callback', controller: :home, action: :get_callback, as: :get_callback
  get '/partner-with-us', controller: :home, action: :partner_with_us, as: :partner_with_us
  get '/onboarding', controller: :home, action: :onboarding, as: :onboarding
  get '/get-sample-tenders', controller: :home, action: :get_sample_tenders, as: :get_sample_tenders
  # get '/free-trial', controller: :home, action: :free_trial, as: :free_trial
  get '/faq', controller: :home, action: :faq, as: :faq

  get '/pricing', controller: :home, action: :pricing, as: :pricing
  get '/cancellation-and-refund-policy', controller: :home, action: :refund_policy, as: :refund_policy
  get '/disclaimer', controller: :home, action: :disclaimer, as: :disclaimer

  # blog
  get '/blog/how-to-file-tenders', controller: :home, action: :how_to_file_tender, as: :how_to_file_tender

  # footer
  get '/privacy-policy', controller: :home, action: :privacy_policy
  get '/terms-and-conditions', controller: :home, action: :terms_and_conditions

  # 404
  # get '*unmatched_route', to: 'home#not_found'
  get '/not-found', to: 'home#not_found'

  # resources :attachments
  # resources :tenders

  get '/categories', controller: :tenders, action: :tender_main_category, as: :tender_main_category
  # sub list
  get '/categories/tender-by-city', controller: :tenders, action: :tender_category_by_city, as: :tender_category_by_city
  get '/categories/tender-by-state', controller: :tenders, action: :tender_category_by_state, as: :tender_category_by_state
  get '/categories/tender-by-sector', controller: :tenders, action: :tender_category_by_sector, as: :tender_category_by_sector
  get '/categories/tender-by-organisation', controller: :tenders, action: :tender_by_organisation, as: :tender_by_organisation
  get '/categories/tender-by-products', controller: :tenders, action: :tender_by_products, as: :tender_by_products

  get '/tenders/:keyword-tenders', controller: :tenders, action: :search, as: :keyword_tender

  get '/trending-tenders', controller: :tenders, action: :trending_tenders, as: :trending_tenders
  get '/get-relevant-tenders', controller: :tenders, action: :get_relevant_tenders, as: :get_relevant_tenders
  # get '/get-relevant-tenders/success', controller: :tenders, action: :get_relevant_tenders_success, as: :get_relevant_tenders_success
  # get relevant keywords
  post '/get-relevant-tenders', controller: :tenders, action: :get_relevant_tenders_post, as: :get_relevant_tenders_post
  post '/checklist-download' => "tenders#checklist_download", as: :checklist_download

  # /search?q=a
  get '/search/autocomplete', controller: :tenders, action: :autocomplete
  get '/search', controller: :tenders, action: :search
  get '/tender/:slug_uuid', controller: :tenders, action: :tender_show, as: :tender_show
  post '/tender/:slug_uuid/like', controller: :tenders, action: :tender_like
  post '/tender/bookmark', controller: :tenders, action: :bookmark_tender

  # get '/tenders-by-state', controller: :home, action: :tenders_by_state
  # get '/tenders-by-sector', controller: :home, action: :tenders_by_sector

  # get '/state/:state', controller: :tenders, action: :state_page
  # get '/sector/:sector', controller: :tenders, action: :sector_page
  # get '/tenders/:keyword', controller: :tenders, action: :sector_page

  # login
  # /queries/tender_result/1
  get '/queries/tender_result/:query_id', controller: :queries, action: :query_result, as: :query_result

  get '/api/download_file', controller: :api, action: :download_file_get
  post '/api/download_file', controller: :api, action: :download_file, as: :download_file
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  #   admin
  get '/admin2', controller: :admin, action: :admin2, as: :admin2
  post '/admin2/login_as', controller: :admin, action: :login_as, as: :login_as

end
