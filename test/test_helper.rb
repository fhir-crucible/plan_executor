require 'simplecov'
require_relative '../lib/plan_executor'

require 'pry'
require 'test/unit'
require 'bundler/setup'

FHIR.logger.level = Logger::ERROR
