# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "plan_executor"
  s.summary = "A Gem for handling FHIR test executions"
  s.description = "A Gem for handling FHIR test executions"
  s.email = "jwalonoski@mitre.org"
  s.homepage = "https://github.com/hl7-fhir/fhir-svn"
  s.authors = ["Andre Quina", "Jason Walonoski", "Janoo Fernandes", "Michael O'Keefe", "Robert Scanlon"]
  s.version = '1.8.0'
  s.license = 'Apache-2.0'

  s.files = s.files = `git ls-files`.split("\n")

  # s.add_runtime_dependency('method_source')
  s.add_runtime_dependency('jsonpath')
  s.add_runtime_dependency('nokogiri', '>= 1.8.2')
  s.add_runtime_dependency('nokogiri-diff')
  s.add_runtime_dependency('fhir_client')
  s.add_runtime_dependency('fhir_models')
  s.add_runtime_dependency('fhir_dstu2_models')
  s.add_runtime_dependency('oauth2')
  s.add_runtime_dependency('rest-client')
  s.add_runtime_dependency('date_time_precision')
  s.add_runtime_dependency('bcp47')

  s.add_development_dependency('tilt')
  s.add_development_dependency('ansi')
  s.add_development_dependency('rake')
  s.add_development_dependency('pry')
  s.add_development_dependency('webmock')
  s.add_development_dependency('simplecov')
  s.add_development_dependency('test-unit')
  s.add_development_dependency('awesome_print')
end
