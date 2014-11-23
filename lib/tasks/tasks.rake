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
        result[suite_key][:tests].each do |test_key, value|
          puts write_result(value['status'], test_key, value['message'])
          puts (' '*10) + value['data'] if (verbose==true) && value['data']
        end

      end

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
