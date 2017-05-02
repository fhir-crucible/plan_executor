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

  desc 'console'
  task :console, [] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    binding.pry
  end

  desc 'execute all'
  task :execute_all, [:url, :html_summary] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'
    b = Benchmark.measure {
      client = FHIR::Client.new(args.url)
      options = client.get_oauth2_metadata_from_conformance
      set_client_secrets(client,options) unless options.empty?
      results = execute_all(client)
      if args.html_summary
        generate_html_summary(args.url, results, "ExecuteAll")
      end
    }
    puts "Execute All completed in #{b.real} seconds."
  end

  desc 'execute all test scripts'
  task :execute_all_testscripts, [:url, :html_summary] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'
    b = Benchmark.measure {
      client = FHIR::Client.new(args.url)
      options = client.get_oauth2_metadata_from_conformance
      set_client_secrets(client,options) unless options.empty?
      results = Crucible::Tests::TestScriptEngine.new(client).execute_all
      output_results results
      if args.html_summary
        generate_html_summary(args.url, results, "ExecuteAll")
      end
    }
    puts "Execute All completed in #{b.real} seconds."
  end

  desc 'execute testscript and get testreport'
  task :testreport, [:url, :test, :filename] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'
    b = Benchmark.measure {
      client = FHIR::Client.new(args.url)
      options = client.get_oauth2_metadata_from_conformance
      set_client_secrets(client,options) unless options.empty?
      engine = Crucible::Tests::TestScriptEngine.new(client)
      script = engine.find_test(args.test)
      if script.nil?
        puts "Unable to find TestScript #{args.test}"
      else
        results = script.execute
        if args.filename
          f = File.open(args.filename,'w:UTF-8')
          f.write(results.values.first.to_json)
          f.close
        end
        puts results.values.first.to_json
      end
    }
    puts "TestReport completed in #{b.real} seconds."
  end

  desc 'execute'
  task :execute, [:url, :test, :resource] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'
    b = Benchmark.measure {
      client = FHIR::Client.new(args.url)
      options = client.get_oauth2_metadata_from_conformance
      set_client_secrets(client,options) unless options.empty?
      execute_test(client, args.test, args.resource)
    }
    puts "Execute #{args.test} completed in #{b.real} seconds."
  end

  desc 'metadata'
  task :metadata, [:test] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'
    b = Benchmark.measure { puts JSON.pretty_unparse(Crucible::Tests::Executor.new(nil).extract_metadata_from_test(args.test)) }
    puts "Metadata #{args.test} completed in #{b.real} seconds."
  end

  def set_client_secrets(client,options)
    puts "Using OAuth2 Options: #{options}"
    print 'Enter client id: '
    client_id = STDIN.gets.chomp
    print 'Enter client secret: '
    client_secret = STDIN.gets.chomp
    if client_id!="" && client_secret!=""
      options[:client_id] = client_id
      options[:client_secret] = client_secret
      # set_oauth2_auth(client,secret,authorizePath,tokenPath)
      client.set_oauth2_auth(options[:client_id],options[:client_secret],options[:authorize_url],options[:token_url])
    else
      puts "Ignoring OAuth2 credentials: empty id or secret. Using unsecured client..."
    end
  end

  def execute_test(client, key, resourceType=nil)
    executor = Crucible::Tests::Executor.new(client)
    test = executor.find_test(key)
    if test.nil? || (test.is_a?(Array) && test.empty?)
      puts "Unable to find test: #{key}"
      return
    end
    results = nil
    if !resourceType.nil? && test.respond_to?(:resource_class=) && FHIR::RESOURCES.include?(resourceType)
      results = test.execute("FHIR::#{resourceType}".constantize)
    end
    results = executor.execute(test) if results.nil?
    output_results results
  end

  # TODO track FHIR::Client and FHIR::Model objects --- memory leak?
  def execute_all(client)
    executor = Crucible::Tests::Executor.new(client)
    all_results = {}
    executor.tests.each do |test|
      next if test.multiserver
      results = executor.execute(test)
      all_results.merge! results
      output_results results
    end
    all_results
  end

  def execute_multiserver_test(client, client2, key)
    executor = Crucible::Tests::Executor.new(client, client2)
    output_results executor.execute(executor.find_test(key))
  end

  def output_results(results, metadata_only=false)
    require 'ansi'
    results.keys.each do |suite_key|
      puts suite_key
      suite = results[suite_key]
      suite = convert_testreport_to_testresults(suite) if suite.is_a?(FHIR::TestReport)
      suite.each do |test|
        puts write_result(test['status'], test[:test_method], test['message'])
        if test['status'].upcase=='ERROR' && test['data']
          puts " "*12 + "-"*40
          puts " "*12 + "#{test['data'].gsub("\n","\n"+" "*12)}"
          puts " "*12 + "-"*40
        end
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
    results
  end

  def convert_testreport_to_testresults(testreport)
    results = []

    if testreport.setup
      statuses = Hash.new(0)
      message = nil
      testreport.setup.action.each do |action|
        if action.operation
          statuses[action.operation.result] += 1
          message = action.operation.message if ['fail','error','skip'].include?(action.operation.result) && message.nil? && action.operation.message
        elsif action.assert
          statuses[action.assert.result] += 1
          message = action.assert.message if ['fail','error','skip'].include?(action.assert.result) && message.nil? && action.assert.message
        end
      end
      if statuses['error'] > 0
        status = 'error'
      elsif statuses['fail'] > 0
        status = 'fail'
      elsif statuses['skip'] > 0
        status = 'skip'
      else
        status = 'pass'
      end
      results << Crucible::Tests::TestResult.new('SETUP', 'Setup for TestScript', status, message, nil).to_hash
      results.last[:test_method] = 'SETUP'
    end

    testreport.test.each do |test|
      statuses = Hash.new(0)
      message = nil
      test.action.each do |action|
        if action.operation
          statuses[action.operation.result] += 1
          message = action.operation.message if ['fail','error','skip'].include?(action.operation.result) && message.nil? && action.operation.message
        elsif action.assert
          statuses[action.assert.result] += 1
          message = action.assert.message if ['fail','error','skip'].include?(action.assert.result) && message.nil? && action.assert.message
        end
      end
      if statuses['error'] > 0
        status = 'error'
      elsif statuses['fail'] > 0
        status = 'fail'
      elsif statuses['skip'] > 0
        status = 'skip'
      else
        status = 'pass'
      end
      results << Crucible::Tests::TestResult.new(test.name, test.description, status, message, nil).to_hash
      results.last[:test_method] = test.name
    end
    results
  end

  def generate_html_summary(url, results, id="summary")
    require 'erb'
    require 'tilt'
    require 'fileutils'
    totals = Hash.new(0)
    metadata = Hash.new(0)
    results.values.each do |suite|
      suite.map{|t| t["status"]}.each_with_object(totals) { |n, h| h[n] += 1}
      suite.map{|t| {k: t["id"], v: t["validates"], s: t["status"]}}.each_with_object(metadata) do |n, h|
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
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'

    puts "# #{args.test}"
    puts

    seconds = 0.0

    FHIR_SERVERS.each do |url|
      puts "## #{url}"
      puts "```"
      b = Benchmark.measure {
        client = FHIR::Client.new(url)
        options = client.get_oauth2_metadata_from_conformance
        set_client_secrets(client,options) unless options.empty?
        results = execute_test(client, args.test, args.resource_type)
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
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'benchmark'

    puts "# #{args.test}"
    puts

    seconds = 0.0

    FHIR_SERVERS.each do |url|
      puts "## #{url}"
      puts "```"
      b = Benchmark.measure {
        client = FHIR::Client.new(url)
        options = client.get_oauth2_metadata_from_conformance
        set_client_secrets(client,options) unless options.empty?
        results = execute_all(client)
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

  desc 'list names of test suites'
  task :list_suites do
    require 'benchmark'
    b = Benchmark.measure do
      suites = Crucible::Tests::Executor.list_all
      suite_names = []
      suites.each do |key,value|
        suite_names << value['author'].split('::').last if !key.start_with?('TS')
      end
      suite_names.uniq!
      suite_names.each {|x| puts "  #{x}"}
    end
    puts "List all suites completed in #{b.real} seconds."
  end

  desc 'list all test scripts'
  task :list_testscripts do
    require 'benchmark'
    b = Benchmark.measure { puts Crucible::Tests::TestScriptEngine.list_all.keys }
    puts "List all tests completed in #{b.real} seconds."
  end

  desc 'execute with requirements'
  task :execute_w_requirements, [:url, :test] do |t, args|
    FHIR.logger = Logger.new("logs/plan_executor.log", 10, 1024000)
    require 'ansi'

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
    options = client.get_oauth2_metadata_from_conformance
    set_client_secrets(client,options) unless options.empty?
    client.monitor_requirements
    test = args.test.to_sym
    execute_test(client, test)
    pp Crucible::Tests::BaseTest.class_variable_get :@@requirements
  end


  def write_result(status, test_name, message)
    tab_size = 10
    "#{' '*(tab_size - status.length)}#{colorize(status)} #{test_name}: #{message}"
  end

  def colorize(status)
    case status.upcase
    when 'PASS'
      ANSI.green{ status.upcase }
    when 'SKIP'
      ANSI.blue{ status.upcase }
    when 'FAIL'
      ANSI.red{ status.upcase }
    else
      ANSI.white_on_red{ status.upcase }
    end
  end

  desc 'update fixtures from spec'
  task :update_fixtures, [:publish_folder] do |t, args|

    # open publish folder
    # open fixtures
    # go through each folder within fixtures
    # if file exists in publish folder, replace it

    root = File.expand_path '../..', File.dirname(File.absolute_path(__FILE__))
    fixtures = File.join(root, 'fixtures')
    publish = File.join(args.publish_folder)

    files = Dir.glob(File.join(fixtures, '**', '*.xml'))
    files.each do |file|
      basename = File.basename(file)
      updated_file = File.join(publish, basename)
      if File.exists?(updated_file)
        puts "Updating Fixture: #{basename}..."
        FileUtils.copy updated_file, file 
      else
        puts "Unable to update fixture: #{basename}"
      end
    end

  end

  namespace :multiserver do
    desc 'execute'
    task :execute, [:url1, :url2, :test] do |t, args|
      FHIR.logger = Logger.new("logs/multiserver.log", 10, 1024000)
      require 'ansi'
      require 'benchmark'
      b = Benchmark.measure {
        client1 = FHIR::Client.new(args.url1)
        options = client1.get_oauth2_metadata_from_conformance
        set_client_secrets(client1,options) unless options.empty?
        client2 = FHIR::Client.new(args.url2)
        options = client2.get_oauth2_metadata_from_conformance
        set_client_secrets(client2,options) unless options.empty?
        execute_multiserver_test(client1, client2, args.test)
      }
      puts "Execute multiserver #{args.test} completed in #{b.real} seconds."
    end
  end

end
