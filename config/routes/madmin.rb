# Below are the routes for madmin
namespace :madmin, path: 'admin' do
  resources :search_queries
  resources :subscriptions
  resources :tenders
  resources :bookmarks
  resources :coupons
  resources :misc_data_stores
  resources :queries
  resources :keyword_pages
  resources :attachments
  resources :admin_users
  resources :users do
    post :impersonate, on: :member
  end
  root to: "dashboard#show"
end
