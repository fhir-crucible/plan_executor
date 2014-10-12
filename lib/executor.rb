module Crucible
	module Tests
    class Executor

      def initialize(client)
        @client = client
      end

      def execute_all
        Crucible::Tests.constants.grep(/Test$/).each do |test|
          Crucible::Tests.const_get(test).new(@client).execute
        end
      end

    end
  end
end
