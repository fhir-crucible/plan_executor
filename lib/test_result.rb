module Crucible
  module Tests
    class TestResult

      attr_accessor :key
      attr_accessor :id
      attr_accessor :description
      attr_accessor :status
      attr_accessor :message
      attr_accessor :data
      attr_accessor :warnings
      attr_accessor :requires
      attr_accessor :validates
      attr_accessor :links

      def initialize(key, description, status, message, data)
        @key = key
        @status = status
        @description = description
        @message = message
        @data = data
      end

      def update(status, message, data)
        @status = status
        @message = message
        @data = data
        self
      end

      def passed?
        return ( (@status==true) or (@status=='passed') )
      end

      def failed?
        !self.passed?
      end

      def to_hash
        hash = {}
        hash['key'] = @key
        hash['id'] = @id || @key
        hash['description'] = force_encoding(@description)
        hash['status'] = force_encoding(@status)
        if @message.class == Array
          hash['message'] = @message.map { |m| force_encoding(m) }
        else
          hash['message'] = force_encoding(@message)
        end
        hash['data'] = force_encoding(@data)
        hash['warnings'] = warnings if warnings
        hash['requires'] = requires if requires
        hash['validates'] = validates if validates
        hash['links'] = links if links
        hash
      end

      private

      def force_encoding(value)
        return nil if value.blank?
        value.force_encoding("UTF-8")
      end

    end
  end
end

