source "http://rubygems.org"
gemspec

gem 'rake'
gem 'pry'
gem 'tilt'
gem 'rails', '>= 4.0.0'
gem 'mongoid'
gem 'mongoid-history'
gem 'nokogiri'
gem 'date_time_precision'
gem 'fhir_model', :git => 'https://github.com/fhir-crucible/fhir_dstu2_models', :branch => 'master'
gem 'fhir_client', git: 'https://github.com/fhir-crucible/fhir_client.git', :branch => 'dstu2'
#gem 'fhir_client', path: '../fhir_client/'
gem 'rest-client'
gem 'webmock'
gem 'builder'

group :test do
  gem 'simplecov', :require => false

  gem 'minitest', "~> 4.0"
  gem 'turn', :require => false
  gem 'awesome_print', :require => 'ap'
end
