module FHIR
	module Tests
    class Executor

      def initialize(client)
        @client = client
      end

      def execute_all
        FHIR::Tests.constants.grep(/Test$/).each do |test|
          FHIR::Tests.const_get(test).new(@client).execute
        end
      end

    end
  end
end
