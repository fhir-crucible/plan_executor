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

      def assert_response_ok(response)
        unless [200, 201].include? response.code
          raise AssertionException.new "Bad response code expected 200, 201, but found: #{response.code}", response.body
        end
      end

      def assert_response_gone(response)
        unless [410].include? response.code
          raise AssertionException.new "Bad response code expected 410, but found: #{response.code}", response.body
        end
      end

      def assert_response_not_found(response)
        unless [404].include? response.code
          raise AssertionException.new "Bad response code expected 404, but found: #{response.code}", response.body
        end
      end

      def assert_navigation_links(bundle)
        unless bundle.first_link && bundle.last_link && bundle.next_link
          raise AssertionException.new "Expecting first, next and last link to be present"
        end
      end

      def assert_bundle_response(response)
        unless response.resource.class == FHIR::Bundle
          raise AssertionException.new "Expected FHIR Bundle but found: #{response.resource.class}", response.body
        end
      end

      def assert_valid_resource_content_type_present(client_reply)
        header = client_reply.response.headers[:content_type]
        
        content_type = header
        charset = encoding = nil
        
        content_type = header[0, header.index(';')] if !header.index(';').nil?
        charset = header[header.index(';charset=')+9..-1] if !header.index(';charset=').nil?
        encoding = Encoding.find(charset) if !charset.nil?
        
        unless encoding == Encoding::UTF_8
          raise AssertionException.new "Response content-type specifies encoding other than UTF-8: #{charset}", header
        end
        unless (content_type == FHIR::Formats::ResourceFormat::RESOURCE_XML) || (content_type == FHIR::Formats::ResourceFormat::RESOURCE_JSON)
          raise AssertionException.new "Invalid FHIR content-type: #{content_type}", header
        end
      end

      def assert_last_modified_present(client_reply)
        header = client_reply.response.headers[:last_modified]
        assert !header.nil?, 'Last-modified HTTP header is missing.'
      end  
      
      def assert_valid_content_location_present(client_reply)
        header = client_reply.response.headers[:content_location]
        assert !header.nil?, 'Content-location HTTP header is missing.'
      end   

      def skip
        raise SkipException.new
      end

    end

    class AssertionException < Exception
      attr_accessor :data
      def initialize(message, data=nil)
        super(message)
        @data = data
      end
    end

    class SkipException < Exception
    end

  end
end
