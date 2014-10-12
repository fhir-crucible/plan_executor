namespace :crucible do

  desc 'execute'
  task :execute, [:url] do |t, args|
    Crucible::Tests::Executor.new(FHIR::Client.new args.url).execute_all
  end

end
