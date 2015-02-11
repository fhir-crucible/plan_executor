module FHIR
  class TestScript

    attr_accessor :engine

    # TODO: Determine multiserver status from destination count
    def multiserver
      false
    end

    def tests
      test.map { |test| "#{test.xmlId} #{test.name} test".downcase.tr(' ', '_').to_sym }
    end

    def execute
      [{name => {
        test_file: name,
        tests: execute_test_methods
        }}]
    end

    def execute_test_methods(test_methods=nil)
      result = []
      execute_setup if !setup.blank? and not @metadata_only
      prefix = if @metadata_only then 'generating metadata' else 'executing' end
      methods = tests
      methods = tests & test_methods unless test_methods.blank?
      methods.each do |test_method|
        puts "[#{name}] #{prefix}: #{test_method}..."
        begin
          result << execute_test_method(test_method)
        rescue => e
          result << Crucible::Tests::TestResult.new('ERROR', "Error #{prefix} #{test_method}",
            Crucible::Tests::BaseTest::STATUS[:error],
            "#{test_method} failed, fatal error: #{e.message}",
            e.backtrace.join("\n")).to_hash.merge!({:test_method => test_method})
        end
      end
      execute_teardown if !teardown.blank? and not @metadata_only
      result
    end

    def execute_setup
      puts "Setting up... #{setup}"
    end

    def execute_test_method(test_method)
      test_item = test.select {|t| "#{t.xmlId} #{t.name} test".downcase.tr(' ', '_').to_sym == test_method}.first
      result = Crucible::Tests::TestResult.new(test_item.xmlId, test_item.name, Crucible::Tests::BaseTest::STATUS[:skip], '','')
      # result.warnings = @warnings  unless @warnings.empty?
      if !test_item.metadata.nil?
        result.requires = test_item.metadata.requires.map {|r| {resource: r.fhirType, methods: r.operations} } if !test_item.metadata.requires.empty?
        result.validates = test_item.metadata.validates.map {|r| {resource: r.fhirType, methods: r.operations} } if !test_item.metadata.requires.empty?
        result.links = test_item.metadata.link.map(&:url) if !test_item.metadata.link.empty?
      end
      result.id = self.object_id.to_s
      result.code = test_item.to_xml

      result.to_hash.merge!({:test_method => test_method})
    end

    def execute_teardown
      puts "Tearing down... #{teardown}"
    end

  end
end
