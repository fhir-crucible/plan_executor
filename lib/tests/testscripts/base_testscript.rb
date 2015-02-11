module Crucible
  module Tests
    class BaseTestScript < BaseTest

      def initialize(testscript)
        @testscript = testscript
        define_tests
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
        @testscript.name
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

      def process_test(test)
        result = TestResult.new(test.xmlId, test.name, STATUS[:pass], '','')
        begin
          puts "Executing #{test.name}"
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
        # @testscript.setup
        puts 'Setup' if !@testscript.setup.blank?
      end

      def teardown
        puts 'Teardown' if !@testscript.teardown.blank?
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
      #
      # def execute_setup
      #   puts "Setting up... #{@testscript.setup}"
      # end
      #
      # def execute_teardown
      #   puts "Tearing down... #{@testscript.teardown}"
      # end

    end
  end
end
