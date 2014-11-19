namespace :crucible do

  desc 'execute all'
  task :execute_all, [:url] do |t, args|
    Crucible::Tests::Executor.new(FHIR::Client.new(args.url)).execute_all
  end

  desc 'execute'
  task :execute, [:url, :test] do |t, args|
    require 'turn'
    results = Crucible::Tests::Executor.new(FHIR::Client.new(args.url)).execute(args.test.to_sym)
    test_results = results.values.first[:tests]

    puts results.keys.first
    test_results.each do |key, value|
      puts write_result(value['status'], key, value['data'])
    end
  end

  desc 'list all'
  task :list_all do
    puts Crucible::Tests::Executor.list_all
  end

  def write_result(status, test_name, description)
    tab_size = 10
    "#{' '*(tab_size - status.length)}#{Turn::Colorize.method(status).call(status.upcase)} #{test_name}: #{description}"
  end

end
