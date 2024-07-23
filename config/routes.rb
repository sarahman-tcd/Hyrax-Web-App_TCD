Rails.application.routes.draw do

  # injection prevetion routes
  root 'hyrax/homepage#index', constraints: AbcParamsConstraint.new
  get '/about', to: 'hyrax/pages#show', constraints: AboutParamsConstraint.new, defaults: { key: 'about' }
  get '/about', to: 'hyrax/pages#show', constraints: AboutNoParamsConstraint.new, defaults: { key: 'about' }

  get '/concern/subseries/:id', to: 'hyrax/subseries#show', constraints: SubseriesParamsConstraint.new
  get '/concern/works/:id', to: 'hyrax/works#show', constraints: SubseriesParamsConstraint.new
  get '/concern/folios/:id', to: 'hyrax/folios#show', constraints: SubseriesParamsConstraint.new

  constraints AboutParamsConstraint.new do
    get '/concern/parent/:parent_id/file_sets/:id', to: 'hyrax/file_sets#show'
    get '/concern/file_sets/:id', to: 'hyrax/file_sets#show'
    get '/concern/parent/:parent_id/works/:id', to: 'hyrax/works#show'
    get '/concern/parent/:parent_id/subseries/:id', to: 'hyrax/subseries#show'
    get '/concern/parent/:parent_id/folios/:id', to: 'hyrax/folios#show'
  end
  get '/collections/:id', to: 'hyrax/collections#show', constraints: CollectionParamsConstraint.new
  
  get '/catalog', to: 'catalog#index', constraints: CatalogParamsConstraint.new

  get '/contact', to:'hyrax/contact_form#new', constraints: AboutParamsConstraint.new
  get '/help', to: 'hyrax/pages#show', constraints: AboutParamsConstraint.new, defaults: { key: 'help' }

  constraints AboutParamsConstraint.new do
    devise_scope :user do
      get '/users/sign_in', to: 'devise/sessions#new'
    end
  end
  
  get '/downloads/:id', to: 'hyrax/downloads#show', constraints: AboutParamsConstraint.new
  get '/export/dublinCore.xml', to: 'export#dublinCore', constraints: DublinCoreParamsConstraint.new
  # get '/iiif/*path', to: 'riiif/images#show', constraints: AboutParamsConstraint.new
  get '/search_assist/index', to: 'search_assist#index', constraints: AboutParamsConstraint.new

  get '/zotero', to: 'hyrax/static#zotero', constraints: AboutParamsConstraint.new
  get '/mendeley', to: 'hyrax/static#mendeley', constraints: AboutParamsConstraint.new

  constraints AboutParamsConstraint.new do
    get '/concern/folios/:id.endnote', to: 'solr_document/export#export_as_endnote', constraints: { id: /[a-zA-Z0-9]+/ }, defaults: { format: :endnote }
    get '/concern/subseries/:id.endnote', to: 'solr_document/export#export_as_endnote', constraints: { id: /[a-zA-Z0-9]+/ }, defaults: { format: :endnote }
    get '/concern/works/:id.endnote', to: 'solr_document/export#export_as_endnote', constraints: { id: /[a-zA-Z0-9]+/ }, defaults: { format: :endnote }
  end

  # For DC Dev - PDF generation is still under development
  get '/pdf/:ocr_checkbox/:file_set_id', to: 'pdf_generation#pdf', as: 'pdf', constraints: AboutParamsConstraint.new

  get 'pdf_generation/check_pdf_file_exists/:file_set_id', to: 'pdf_generation#check_pdf_file_exists', constraints: AboutParamsConstraint.new
  # End

  # #For Live
  # get '/pdf/:file_set_id', to: 'pdf_generation#pdf', as: 'pdf', constraints: AboutParamsConstraint.new

  # get 'pdf_generation/check_pdf_file_exists/:file_set_id', to: 'pdf_generation#check_pdf_file_exists', constraints: AboutParamsConstraint.new
  # # End

  constraints IIIFParamsConstraint.new do
    get '/iiif/2/*path', to: 'riiif/images#show', format: false
  end
  #end here



  post 'catalog/save_tile_order', to: 'catalog#save_tile_order'
  get 'catalog/get_title_orders', to: 'catalog#get_title_orders'
  
  # get 'pdf_generation/solrdata', to: 'pdf_generation#solrdata'

  #get 'image_display_names/new'
  resources :image_display_names, :only => [ :new, :create ]

  get 'folder_numbers/index'

  get 'folder_numbers/show'

  get 'folder_numbers/new'

  get 'folder_numbers/edit'

  #get 'doi_blocker_lists/index'

  get 'search_assist/index'

  resources :hyrax_checksums, :only => [ :index, :create, :update ]
  resources :doi_blocker_lists, :only => [ :index ]

  resources :folder_numbers do
    member do
      get :delete
    end
    collection do
      get :export
    end
  end

  mount Bulkrax::Engine, at: '/'
  resources :ingests

  get 'import/index'

  get 'search_tips' => 'hyrax/pages#show', key: 'search_tips'

  # TODO: remove get import/picker
  get 'import/picker'

  post 'import/picker'
  get 'export/dublinCore'
  get 'export_bulk/dublinCore'
  get 'doi/createDoi'

  mount Riiif::Engine => 'images', as: :riiif if Hyrax.config.iiif_image_server?
  mount Blacklight::Engine => '/'

    concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
  end

  devise_for :users
  mount Hydra::RoleManagement::Engine => '/'

  mount Qa::Engine => '/authorities'
  mount Hyrax::Engine, at: '/'
  resources :welcome, only: 'index'
  # root 'hyrax/homepage#index'
  curation_concerns_basic_routes
  concern :exportable, Blacklight::Routes::Exportable.new

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end

  require 'sidekiq/web'
  require 'sidekiq/cron/web'
  #mount Sidekiq::Web => '/sidekiq'
  # config/routes.rb
  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  mount BrowseEverything::Engine => '/browse'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html 
end
