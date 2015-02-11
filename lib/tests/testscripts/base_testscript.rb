module Crucible
  module Tests
    class BaseTestScript < BaseTest

      def initialize(testscript, client, client2=nil)
        super(client, client2)
        @testscript = testscript
        define_tests
        load_fixtures
        @id_map = {}
      end

      def author
        @testscript.name
      end

      def description
        @testscript.description
      end

      def id
        @testscript.xmlId
      end

      def title
        id
      end

      def tests
        @testscript.test.map { |test| "#{test.xmlId} #{test.name} test".downcase.tr(' ', '_').to_sym }
      end

      def define_tests
        @testscript.test.each do |test|
          test_method = "#{test.xmlId} #{test.name} test".downcase.tr(' ', '_').to_sym
          define_singleton_method test_method, -> { process_test(test) }
        end
      end

      def load_fixtures
        @fixtures = {}
        @testscript.fixture.each do |fixture|
          # FIXME: Determine fixture data resource class dynamically!
          @fixtures[fixture.xmlId] = Generator::Resources.new.load_fixture(fixture.uri, "Patient".to_sym)
        end
      end

      def process_test(test)
        result = TestResult.new(test.xmlId, test.name, STATUS[:pass], '','')
        begin
          test.operation.each do |op|
            execute_operation op
          end
          # result.update(t.status, t.message, t.data) if !t.nil? && t.is_a?(Crucible::Tests::TestResult)
        rescue AssertionException => e
          result.update(STATUS[:fail], e.message, e.data)
        rescue => e
          result.update(STATUS[:error], "Fatal Error: #{e.message}", e.backtrace.join("\n"))
        end
        if !test.metadata.nil?
          result.requires = test.metadata.requires.map {|r| {resource: r.fhirType, methods: r.operations} } if !test.metadata.requires.empty?
          result.validates = test.metadata.validates.map {|r| {resource: r.fhirType, methods: r.operations} } if !test.metadata.requires.empty?
          result.links = test.metadata.link.map(&:url) if !test.metadata.link.empty?
        end
        result
      end

      def setup
        return if @testscript.setup.blank?
        @testscript.setup.operation.each do |op|
          execute_operation op
        end
      end

      def teardown
        return if @testscript.teardown.blank?
        @testscript.teardown.operation.each do |op|
          execute_operation op
        end
      end

      def execute_operation(operation)
        return if @client.nil?
        case operation.fhirType
        when 'create'
          @last_response = @client.create @fixtures[operation.source]
          @id_map[operation.source] = @last_response.id
        when 'read'
          @last_response = @client.read @fixtures[operation.target].class, @id_map[operation.target]
        when 'delete'
          @client.destroy(FHIR::Condition, @cond1_reply.id) if !@cond1_id.nil?
          @last_response = @client.destroy @fixtures[operation.target].class, @id_map[operation.target]
          @id_map.delete(operation.target)
        when 'assertion'
          assertion = "assert_#{operation.parameter}".to_sym
          if self.methods.include?(assertion)
            self.method(assertion).call(@last_response)
          else
            raise "Undefined assertion for #{@testscript.name}-#{title}: #{assertion}"
          end
        end
      end

      #
      # def execute_test_method(test_method)
      #   test_item = @testscript.test.select {|t| "#{t.xmlId} #{t.name} test".downcase.tr(' ', '_').to_sym == test_method}.first
      #   result = Crucible::Tests::TestResult.new(test_item.xmlId, test_item.name, Crucible::Tests::BaseTest::STATUS[:skip], '','')
      #   # result.warnings = @warnings  unless @warnings.empty?
      #
      #   result.id = self.object_id.to_s
      #   result.code = test_item.to_xml
      #
      #   result.to_hash.merge!({:test_method => test_method})
      # end

    end
  end
end
