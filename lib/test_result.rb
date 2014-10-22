module Crucible
  module Tests
    class TestResult

      attr_accessor :id
      attr_accessor :description
      attr_accessor :status
      attr_accessor :message
      attr_accessor :data

      def initialize(id, description, status, message, data)
        @id = id
        @status = status
        @description = description
        @message = message
        @data = data
      end

      def passed?
        return ( (@status==true) or (@status=='passed') )
      end

      def failed?
        !self.passed?
      end

      def to_hash
        hash = {}
        hash['id'] = @id
        hash['description'] = @description
        hash['status'] = @status
        hash['message'] = @message
        hash['data'] = @data
        hash
      end

    end
  end
end

