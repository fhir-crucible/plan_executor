# Top level include file that brings in all the necessary code
require 'bundler/setup'
require 'rubygems'
require 'yaml'
require 'nokogiri'
require 'fhir_model'
require 'fhir_client'

require_relative File.join('.','executor.rb')
require_relative File.join('.','test_result.rb')
require_relative File.join('.','resource_generator.rb')

root = File.expand_path '..', File.dirname(File.absolute_path(__FILE__))
Dir.glob(File.join(root, 'lib','tests','**','*.rb')).each do |file|
  require file
end

Dir.glob(File.join(root, 'lib','data','**','*.rb')).each do |file|
  require file
end

Dir.glob(File.join(root, 'lib','ext','**','*.rb')).each do |file|
  require file
end
