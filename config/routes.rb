Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get "health", to: "health#show"
      resources :employees, only: %i[index create show update] do
        resources :salary_records, only: %i[index create]
      end
      get "insights/average_salary_by_country", to: "insights#average_salary_by_country"
      get "insights/total_salary_by_department", to: "insights#total_salary_by_department"
      get "insights/salary_increases", to: "insights#salary_increases"
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
