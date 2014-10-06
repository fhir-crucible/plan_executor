# Top level include file that brings in all the necessary code
require 'bundler/setup'
require 'rubygems'
require 'yaml'
require 'nokogiri'
require 'fhir_model'
require 'fhir_client'

require_relative File.join('.','executor.rb')

root = File.expand_path '..', File.dirname(File.absolute_path(__FILE__))
Dir.glob(File.join(root, 'lib','tests','**','*.rb')).each do |file|
  require file
end
