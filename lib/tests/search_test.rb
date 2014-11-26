module Crucible
  module Tests
    class SearchTest < BaseTest
 
      attr_accessor :resource_class

      def execute(resource_class=nil)
        if resource_class
          @resource_class = resource_class
          [{"SearchTest_#{resource_class.name.demodulize}" => {
            test_file: test_name,
            tests: execute_resource
          }}]
        else
          fhir_resources.map do | klass |
            @resource_class = klass
            {"SearchTest_#{resource_class.name.demodulize}" => {
              test_file: test_name,
              tests: execute_resource
            }}
          end
        end
      end

      def id
        "SearchTest_#{resource_class}"
      end

      def description
        "Execute suite of searches for #{resource_class.name.demodulize} resources."
      end

      def execute_resource()
        execute_test_methods()
      end

      def supplement_test_description(desc)
        "#{desc} #{resource_class.name.demodulize}"
      end

      # 
      # Search Test
      # 1. First, get the conformance statement.
      # 2. Lookup the allowed search parameters for each resource.
      # 3. Perform suite of tests against each resource.
      #

      #
      # Test the extent of the search capabilities supported.
      # no criteria [SE01]
      # non-existing resource [SE02]
      # id
      # parameters [SE03,SE04,SE24,SE25]
      # parameter modifiers (:missing, :exact, :text, :[type]) [SE23]
      # numbers (= >= significant-digits) [SE21,SE22]
      # date (all of the permutations?)
      # token
      # quantities [SE21,SE22]
      # references [SE05]
      # chained parameters
      # composite parameters
      # text search logical operators
      # tags [TA08], profile, security label
      # _filter parameter
      # result relevance
      # result sorting (_sort parameter)
      # result paging
      # _include parameter [SE06]
      # _summary parameter
      # result server conformance (report params actually used)
      # advanced searching with "Query" or _query param
      #       
      test 'SE01', 'Search for existing' do
        skip
      end


    end
  end
end
