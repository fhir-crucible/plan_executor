module Crucible
  module Tests
    class TestScriptEngine

      def initialize(client, client2=nil)
        @client = client
        @client2 = client2
      end

      def self.list_all
        {}
      end

      def list_all_with_conformance(multiserver=false, metadata=nil)
      	{}
      end

      def tests
        []
      end

      def find_test(key)
        []
      end

    end
  end
end