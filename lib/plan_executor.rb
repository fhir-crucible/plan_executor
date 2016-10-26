# OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

# Top level include file that brings in all the necessary code
require 'bundler/setup'
require 'rubygems'
require 'yaml'
require 'nokogiri'
require 'logger'
require 'fhir_client'
require 'nokogiri/diff'
require 'active_support/inflector'
require 'active_support/core_ext'

require_relative File.join('.','executor.rb')
require_relative File.join('.','test_result.rb')
require_relative File.join('.','resource_generator.rb')
require_relative File.join('.','daf_resource_generator.rb')
require_relative File.join('tests','assertions.rb')
require_relative File.join('tests','base_test.rb')
require_relative File.join('tests','suites','base_suite.rb')
require_relative File.join('tests','testscripts','base_testscript.rb')

root = File.expand_path '..', File.dirname(File.absolute_path(__FILE__))

Dir.glob(File.join(root, 'lib','data','**','*.rb')).each do |file|
  require file
end

Dir.glob(File.join(root, 'lib','ext','**','*.rb')).each do |file|
  require file
end

Dir.glob(File.join(root, 'lib','tests','**','*.rb')).each do |file|
  require file
end
