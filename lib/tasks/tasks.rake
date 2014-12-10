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


  def execute_test(client, test)
    results = Crucible::Tests::Executor.new(client).execute(test)

    binding.pry
    results.each do |result|

      result.keys.each do |suite_key|
        puts suite_key
        result[suite_key][:tests].each do |test|
          puts write_result(test['status'], test[:test_method], test['message'])

          puts (test['warnings'].map { |w| "#{(' '*10)}WARNING: #{w}" }).join("\n") if (verbose==true) && test['warnings']
          puts (' '*10) + test['data'] if (verbose==true) && test['data']
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

end
