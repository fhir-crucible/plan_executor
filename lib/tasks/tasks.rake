namespace :crucible do

  desc 'execute all'
  task :execute_all, [:url] do |t, args|
    Crucible::Tests::Executor.new(FHIR::Client.new(args.url)).execute_all
  end

  desc 'execute'
  task :execute, [:url, :test] do |t, args|
    require 'turn'
    results = Crucible::Tests::Executor.new(FHIR::Client.new(args.url)).execute(args.test.to_sym)

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

  def write_result(status, test_name, message)
    tab_size = 10
    "#{' '*(tab_size - status.length)}#{Turn::Colorize.method(status.to_sym).call(status.upcase)} #{test_name}: #{message}"
  end

end
