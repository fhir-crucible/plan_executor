module Crucible
  module Tests
    module Assertions

      def assert(test, message="assertion failed, no message", data="")
        unless test
          raise AssertionException.new message, data
        end
      end

      def assert_equal(expected, actual, message="", data="")
        unless expected == actual
          message += " Expected: #{expected}, but found: #{actual}."
          raise AssertionException.new message, data
        end
      end

      def skip
        raise SkipException.new
      end

    end

    class AssertionException < Exception
      attr_accessor :data
      def initialize(message, data)
        super(message)
        @data = data
      end
    end

    class SkipException < Exception
    end

  end
end
