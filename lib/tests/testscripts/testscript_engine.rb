module Crucible
  module Tests
    class TestScriptEngine

      @@models = []

      def initialize(client=nil, client2=nil)
        @client = client
        @client2 = client2
        @scripts = []
        load_testscripts
      end

      def tests
        @scripts.select{|test| !test.multiserver && !test.containsRuleAssertions?}
      end

      def find_test(key)
        @scripts.find{|s| s.id == key || s.title == key}
      end

      def execute_all
        results = {}
        self.tests.each do |test|
          if test.multiserver
            puts "Skipping Multiserver TestScript: #{test.id}"
            FHIR.logger.info "Skipping Multiserver TestScript: #{test.id}"
          elsif test.containsRuleAssertions?
            puts "Skipping TestScript with permanently-unsupported Rule/RuleSet Assertions: #{test.id}"
            FHIR.logger.info "Skipping TestScript with permanently-unsupported Rule/RuleSet Assertions: #{test.id}"            
          else
            puts "Executing: #{test.id}"
            FHIR.logger.info "Executing: #{test.id}"
            results.merge! test.execute
          end
        end
        results
      end

      def self.list_all(metadata=false)
        list = {}
        # TODO: Determine if we need resource-based testscript listing support
        TestScriptEngine.new.tests.each do |test|
          list[test.title] = {}
          BaseTest::JSON_FIELDS.each {|field| list[test.title][field] = test.send(field)}
          if metadata
            test_metadata = test.collect_metadata(true)
            BaseTest::METADATA_FIELDS.each do |field|
              field_hash = {}
              test_metadata.values.first.each { |tm| field_hash[tm[:test_method]] = tm[field] }
              list[test.title][field] = field_hash
            end
          end
        end
        list
      end

      def load_testscripts
        return unless @scripts.empty?
        @@models.each do |model|
          @scripts << BaseTestScript.new(model, @client, @client2)
        end
      end

      def self.parse_testscripts
        return unless @@models.empty?
        # get all specification example TestScripts
        root = File.expand_path '.', File.dirname(File.absolute_path(__FILE__))
        path = File.join(root, 'scripts', 'spec', '**/*.xml')
        script_files = Dir.glob(path)
        # get all the Connectathon TestScripts
        path = File.join(root, 'scripts', 'connectathon', '**/*.xml')
        script_files += Dir.glob(path)

        script_files.each do |f|
          begin
            script = FHIR.from_contents( File.read(f) )
            if script.is_a?(FHIR::TestScript) && script.is_valid?
              script.url = f # replace the URL with the local file path so file system references can properly resolve
              @@models << script
              FHIR.logger.info "TestScriptEngine.parse_testscripts: Loaded #{f}"
            elsif script.is_a?(FHIR::TestScript)
              FHIR.logger.error "TestScriptEngine.parse_testscripts: Skipping invalid TestScript #{f}"
            else # this is a fixture...
              FHIR.logger.warn "TestScriptEngine.parse_testscripts: Skipping fixture #{f}"
            end
          rescue
            FHIR.logger.error "TestScriptEngine.parse_testscripts: Exception deserializing TestScript #{f}"
          end
        end
      end
    end
  end
end
Crucible::Tests::TestScriptEngine.parse_testscripts
