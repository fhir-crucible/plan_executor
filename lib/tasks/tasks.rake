namespace :crucible do

  desc 'execute all'
  task :execute_all, [:url] do |t, args|
    require 'benchmark'
    b = Benchmark.measure { Crucible::Tests::Executor.new(FHIR::Client.new(args.url)).execute_all }
    puts "Execute All completed in #{b.real} seconds."
  end

  desc 'execute'
  task :execute, [:url, :test] do |t, args|
    require 'turn'
    require 'benchmark'
    b = Benchmark.measure { execute_test(FHIR::Client.new(args.url), args.test) }
    puts "Execute #{args.test} completed in #{b.real} seconds."
  end

  desc 'metadata'
  task :metadata, [:url, :test] do |t, args|
    require 'turn'
    require 'benchmark'
    b = Benchmark.measure { collect_metadata(FHIR::Client.new(args.url), args.test) }
    puts "Metadata #{args.test} completed in #{b.real} seconds."
  end

  desc 'generate ctl'
  task :generate_ctl do |t, args|
    require 'benchmark'
    b = Benchmark.measure { Crucible::Tests::Executor.generate_ctl }
    puts "CTL generated in #{b.real} seconds."
  end

  desc 'generate test scripts'
  task :generate_ts do |t, args|
    require 'benchmark'
    b = Benchmark.measure { Crucible::Tests::Executor.generate_all_testscripts }
    puts "Test Scripts generated in #{b.real} seconds."
  end

  def execute_test(client, key)
    executor = Crucible::Tests::Executor.new(client)
    output_results executor.execute(executor.find_test(key))
  end

  def execute_multiserver_test(client, client2, key)
    executor = Crucible::Tests::Executor.new(client, client2)
    output_results executor.execute(executor.find_test(key))
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

          if (metadata_only==true)
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
    require 'turn'
    require 'benchmark'

    urls = [
      # DSTU1
      # 'http://fhir.healthintersections.com.au/open',
      # 'http://bonfire.mitre.org:8080/fhir',
      # 'http://spark.furore.com/fhir',
      # 'http://nprogram.azurewebsites.net',
      # 'https://fhir-api.smartplatforms.org',
      # 'https://fhir-open-api.smartplatforms.org',
      # 'https://fhir.orionhealth.com/blaze/fhir',
      # 'http://worden.globalgold.co.uk:8080/FHIR_a/farm/cobalt',
      # 'http://worden.globalgold.co.uk:8080/FHIR_a/farm/bronze',
      # 'http://fhirtest.uhn.ca/base'

      # DSTU2
      'http://bonfire.mitre.org:8090/fhir-dstu2',
      'http://fhirtest.uhn.ca/baseDstu2',
      'http://zm.oridashi.com.au',
      'http://demo.oridashi.com.au:8290',
      'http://demo.oridashi.com.au:8291'
    ]

    puts "# #{args.test}"
    puts

    seconds = 0.0

    urls.each do |url|
      # TrackOneTest
      puts "## #{url}"
      puts "```"
      b = Benchmark.measure { output_results(Crucible::Tests::Executor.new(FHIR::Client.new(url)).execute(args.test), true) }
      seconds += b.real
      puts "```"
      puts
      # Rake::Task['crucible:metadata'].invoke(url, args.test)
      # Rake::Task['crucible:metadata'].reenable
    end
    puts "Execute Custom #{args.test} completed for all servers in #{seconds} seconds."
  end

  desc 'list all'
  task :list_all do
    require 'turn'
    require 'benchmark'
    b = Benchmark.measure { puts Crucible::Tests::Executor.list_all }
    puts "List all tests completed in #{b.real} seconds."
  end

  desc 'list all with conformance'
  task :list_all_w_conf, [:url1, :url2] do |t, args|
    require 'turn'
    require 'benchmark'
    b = Benchmark.measure {
      client = FHIR::Client.new(args.url1)
      client2 = FHIR::Client.new(args.url2) if !args.url2.nil?
      executor = Crucible::Tests::Executor.new(client, client2)
      puts executor.list_all_with_conformance(!args.url2.nil?)
    }
    puts "List all tests with conformance from #{args.url} completed in #{b.real} seconds."
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
      require 'benchmark'
      b = Benchmark.measure { execute_multiserver_test(FHIR::Client.new(args.url1), FHIR::Client.new(args.url2), args.test) }
      puts "Execute multiserver #{args.test} completed in #{b.real} seconds."
    end
  end

end
