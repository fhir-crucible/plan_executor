namespace :fhir do

  desc 'execute'
  task :execute, [:url] do |t, args|
    FHIR::Tests::Executor.new(FHIR::Client.new args.url).execute_all
  end

end
