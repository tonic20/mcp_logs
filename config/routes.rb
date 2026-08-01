McpLogs::Engine.routes.draw do
  root to: "calls#index"

  resources :calls, only: [:index, :show]

  get "docs", to: "docs#show", as: :docs
end
