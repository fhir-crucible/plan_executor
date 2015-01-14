namespace :crucible do

  desc 'execute all'
  task :execute_all, [:url] do |t, args|
    Crucible::Tests::Executor.new(FHIR::Client.new(args.url)).execute_all
  end

  desc 'execute'
  task :execute, [:url, :test] do |t, args|
    require 'turn'
    execute_test(FHIR::Client.new(args.url), args.test.to_sym)
  end

  desc 'metadata'
  task :metadata, [:url, :test] do |t, args|
    require 'turn'
    collect_metadata(FHIR::Client.new(args.url), args.test.to_sym)
  end

  desc 'generate ctl'
  task :generate_ctl do |t, args|
    Crucible::Tests::Executor.generate_ctl
  end


  def execute_test(client, test)
    output_results Crucible::Tests::Executor.new(client).execute(test)
  end
  def execute_multiserver_test(client, client2, test)
    output_results Crucible::Tests::Executor.new(client, client2).execute(test)
  end

  def collect_metadata(client, test)
    output_results Crucible::Tests::Executor.new(client).metadata(test), true
  end

  def output_results(results, metadata_only=false)
    results.each do |result|

      result.keys.each do |suite_key|
        puts suite_key
        result[suite_key][:tests].each do |test|
          puts write_result(test['status'], test[:test_method], test['message'])

          if (verbose==true)
            # warnings
            puts (test['warnings'].map { |w| "#{(' '*10)}WARNING: #{w}" }).join("\n") if test['warnings']
            # metadata
            puts (test['links'].map { |w| "#{(' '*10)}Link: #{w}" }).join("\n") if test['links']
            puts (test['requires'].map { |w| "#{(' '*10)}Requires: #{w[:resource]}: #{w[:methods]}" }).join("\n") if test['requires']
            puts (test['validates'].map { |w| "#{(' '*10)}Validates: #{w[:resource]}: #{w[:methods]}" }).join("\n") if test['validates']
            # data
            puts (' '*10) + test['data'] if test['data']
          end
        end

      end

    end
  end

  desc 'execute custom'
  task :execute_custom, [:test] do |t, args|

    urls = [
      'http://fhir.healthintersections.com.au/open',
      'http://bonfire.mitre.org:8080/fhir',
      'http://spark.furore.com/fhir',
      # 'http://nprogram.azurewebsites.net',
      # 'https://fhir-api.smartplatforms.org',
      # 'https://fhir-open-api.smartplatforms.org',
      # 'https://fhir.orionhealth.com/blaze/fhir',
      # 'http://worden.globalgold.co.uk:8080/FHIR_a/farm/cobalt',
      # 'http://worden.globalgold.co.uk:8080/FHIR_a/farm/bronze',
      # 'http://fhirtest.uhn.ca/base'
    ]

    urls.each do |url|
      Rake::Task['crucible:execute'].invoke(url, args.test)
      Rake::Task['crucible:execute'].reenable
    end
  end

  desc 'list all'
  task :list_all do
    puts Crucible::Tests::Executor.list_all
  end

  desc 'execute with requirements'
  task :execute_w_requirements, [:url, :test] do |t, args|
    require 'turn'

    module Crucible
      module Tests
        class BaseTest

          alias execute_test_method_orig execute_test_method

          def execute_test_method(test_method)
            r = execute_test_method_orig(test_method)
            @@requirements ||= {}
            @@requirements[self.class.name] ||= {}
            @@requirements[self.class.name][test_method] = @client.requirements
            @client.clear_requirements
            r
          end

        end
      end
    end

    client = FHIR::Client.new(args.url)
    client.monitor_requirements
    test = args.test.to_sym
    execute_test(client, test)
    pp Crucible::Tests::BaseTest.class_variable_get :@@requirements
  end


  def write_result(status, test_name, message)
    tab_size = 10
    "#{' '*(tab_size - status.length)}#{Turn::Colorize.method(status.to_sym).call(status.upcase)} #{test_name}: #{message}"
  end

  namespace :multiserver do
    desc 'execute'
    task :execute, [:url1, :url2, :test] do |t, args|
      require 'turn'
      execute_multiserver_test(FHIR::Client.new(args.url1), FHIR::Client.new(args.url2), args.test.to_sym)
    end
  end

end
