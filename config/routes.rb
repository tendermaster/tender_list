Rails.application.routes.draw do
  resources :queries

  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  # devise_for :users
  # nav
  get '/about', controller: :home, action: :about
  get '/login', controller: :home, action: :login
  get '/signup', controller: :home, action: :signup
  get '/services', controller: :home, action: :services
  get '/coming-soon', controller: :home, action: :coming_soon
  get '/get-callback', controller: :home, action: :get_callback, as: :get_callback
  get '/get-sample-tenders', controller: :home, action: :get_sample_tenders, as: :get_sample_tenders
  get '/faq', controller: :home, action: :faq, as: :faq

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

  # /
  root controller: :tenders, action: :home

  get '/categories', controller: :tenders, action: :tender_main_category, as: :tender_main_category
  # sub list
  get '/categories/tender-by-city', controller: :tenders, action: :tender_category_by_city, as: :tender_category_by_city
  get '/categories/tender-by-state', controller: :tenders, action: :tender_category_by_state, as: :tender_category_by_state
  get '/categories/tender-by-organization', controller: :tenders, action: :tender_category_by_organization, as: :tender_category_by_organization
  get '/categories/tender-by-sector', controller: :tenders, action: :tender_category_by_sector, as: :tender_category_by_sector

  get '/tenders/:keyword-tenders', controller: :tenders, action: :search, as: :keyword_tender

  # /search?q=a
  get '/search', controller: :tenders, action: :search
  get '/tender/:slug_uuid', controller: :tenders, action: :tender_show
  post '/tender/:slug_uuid/like', controller: :tenders, action: :tender_like
  # get '/tenders-by-state', controller: :home, action: :tenders_by_state
  # get '/tenders-by-sector', controller: :home, action: :tenders_by_sector

  # get '/state/:state', controller: :tenders, action: :state_page
  # get '/sector/:sector', controller: :tenders, action: :sector_page
  # get '/tenders/:keyword', controller: :tenders, action: :sector_page

  # login
  # /queries/tender_result/1
  get '/queries/tender_result/:query_id', controller: :queries, action: :query_result, as: :query_result

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
