# Below are the routes for madmin
namespace :madmin, path: 'admin' do
  resources :search_queries
  resources :subscriptions
  resources :tenders
  resources :bookmarks
  resources :coupons
  resources :misc_data_stores
  resources :queries
  resources :attachments
  resources :admin_users
  resources :users
  root to: "dashboard#show"
end
