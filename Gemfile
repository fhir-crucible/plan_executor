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
gem 'fhir_model', path: '../fhir_dstu1/implementations/ruby/output/model/'
gem 'fhir_client', git: 'https://gitlab.mitre.org/tof/fhir_client.git'
#gem 'fhir_client', path: '../fhir_client/'
gem 'rest-client'

group :test do
  gem 'simplecov', :require => false

  gem 'minitest', "~> 4.0"
  gem 'turn', :require => false
  gem 'awesome_print', :require => 'ap'
end

