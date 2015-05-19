namespace :crucible do

  FHIR_SERVERS = [
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
    'https://fhir-api-dstu2.smarthealthit.org',
    'http://fhirtest.uhn.ca/baseDstu2',
    'http://bp.oridashi.com.au',
    'http://md.oridashi.com.au',
    'http://zm.oridashi.com.au',
    'http://wildfhir.aegis.net/fhir2',
    'http://fhir-dev.healthintersections.com.au/open'
  ]

  desc 'execute all'
  task :execute_all, [:url, :html_summary] do |t, args|
    require 'benchmark'
    b = Benchmark.measure {
      results = execute_all(FHIR::Client.new(args.url))
      if args.html_summary
        generate_html_summary(args.url, results, "ExecuteAll")
      end
    }
    puts "Execute All completed in #{b.real} seconds."
  end

  desc 'execute'
  task :execute, [:url, :test, :resource] do |t, args|
    require 'benchmark'
    b = Benchmark.measure { execute_test(FHIR::Client.new(args.url), args.test, args.resource) }
    puts "Execute #{args.test} completed in #{b.real} seconds."
  end

  desc 'metadata'
  task :metadata, [:url, :test] do |t, args|
    require 'benchmark'
    b = Benchmark.measure { collect_metadata(FHIR::Client.new(args.url), args.test) }
    puts "Metadata #{args.test} completed in #{b.real} seconds."
  end

  def execute_test(client, key, resourceType=nil)
    executor = Crucible::Tests::Executor.new(client)
    test = executor.find_test(key)
    results = nil
    if !resourceType.nil? && test.respond_to?(:resource_class=)
      fhir_classes = Mongoid.models.select {|c| c.name.include? 'FHIR'}
      klass = fhir_classes.find{|x|x.to_s.include?(resourceType)}
      results = test.execute(klass) if !klass.nil?
    end
    results = executor.execute(test) if results.nil?
    output_results results
  end

  def execute_all(client)
    results = Crucible::Tests::Executor.new(client).execute_all
    output_results results
  end

  def execute_multiserver_test(client, client2, key)
    executor = Crucible::Tests::Executor.new(client, client2)
    output_results executor.execute(executor.find_test(key))
  end

  def collect_metadata(client, test)
    output_results Crucible::Tests::Executor.new(client).metadata(test), true
  end

  def output_results(results, metadata_only=false)
    require 'turn'
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

  def generate_html_summary(url, results, id="summary")
    require 'erb'
    require 'tilt'
    require 'fileutils'
    totals = Hash.new(0)
    metadata = Hash.new(0)
    results.each do |result|
      suite = result.values.first
      suite[:tests].map{|t| t["status"]}.each_with_object(totals) { |n, h| h[n] += 1}
      suite[:tests].map{|t| {k: t["id"], v: t["validates"], s: t["status"]}}.each_with_object(metadata) do |n, h|
        n[:v].each do |val|
          resource = val[:resource].try(:titleize).try(:downcase)
          test_key = n[:k]
          h[resource] = {pass: [], fail: [], error: [], skip: []} unless h.keys.include?(resource)
          h[resource][n[:s].to_sym] << test_key
          val[:methods].each do |meth|
            h[meth] = {pass: [], fail: [], error: [], skip: []} unless h.keys.include?(meth)
            h[meth][n[:s].to_sym] << test_key
          end if val[:methods]
          val[:formats].each do |format|
            h[format] = {pass: [], fail: [], error: [], skip: []} unless h.keys.include?(format)
            h[format][n[:s].to_sym] << test_key
          end if val[:formats]
        end if n[:v]
      end
    end
    template = Tilt.new(File.join(File.dirname(__FILE__), "templates", "summary.html.erb"))
    timestamp = Time.now
    summary = template.render(self, {:results => results, :timestamp => timestamp.strftime("%D %r"), :totals => totals, :url => url, :metadata => metadata})
    summary_file = "#{id}_#{url.gsub(/[^a-z0-9]/,'-')}_#{timestamp.strftime("%m-%d-%y_%H-%M-%S")}.html"
    FileUtils::mkdir_p("html_summaries/#{id}")
    File.write("html_summaries/#{id}/#{summary_file}", summary)
    system("open html_summaries/#{id}/#{summary_file}")
  end

  desc 'execute custom'
  task :execute_custom, [:test, :resource_type, :html_summary] do |t, args|
    require 'benchmark'

    puts "# #{args.test}"
    puts

    seconds = 0.0

    FHIR_SERVERS.each do |url|
      puts "## #{url}"
      puts "```"
      b = Benchmark.measure {
        results = execute_test(FHIR::Client.new(url), args.test, args.resource_type)
        if args.html_summary
          generate_html_summary(url, results, args.test)
        end
      }
      seconds += b.real
      puts "```"
      puts
    end
    puts "Execute Custom #{args.test} completed for #{FHIR_SERVERS.length} servers in #{seconds} seconds."
  end

  desc 'execute all custom'
  task :execute_all_custom, [:html_summary] do |t, args|
    require 'benchmark'

    puts "# #{args.test}"
    puts

    seconds = 0.0

    FHIR_SERVERS.each do |url|
      puts "## #{url}"
      puts "```"
      b = Benchmark.measure {
        results = execute_all(FHIR::Client.new(url))
        if args.html_summary
          generate_html_summary(url, results, "ExecuteAll")
        end
      }
      seconds += b.real
      puts "```"
      puts
    end
    puts "Execute All Custom #{args.test} completed for #{FHIR_SERVERS.length} servers in #{seconds} seconds."
  end

  desc 'list all'
  task :list_all do
    require 'benchmark'
    b = Benchmark.measure { puts Crucible::Tests::Executor.list_all }
    puts "List all tests completed in #{b.real} seconds."
  end

  desc 'list all with conformance'
  task :list_all_w_conf, [:url1, :url2] do |t, args|
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
