module Crucible
  module Tests
    module Assertions

      def assert(test, message="assertion failed, no message", data="")
        unless test
          raise AssertionException.new message, data
        end
      end

      def assert_equal(expected, actual, message="", data="")
        unless assertion_bool( expected == actual )
          message += " Expected: #{expected}, but found: #{actual}."
          raise AssertionException.new message, data
        end
      end

      def assert_response_ok(response, error_message="")
        unless assertion_bool( [200, 201].include?(response.code) )
          raise AssertionException.new "Bad response code expected 200, 201, but found: #{response.code}.#{" " + error_message}", response.body
        end
      end

      def assert_response_created(response, error_message="")
        unless assertion_bool( [201].include?(response.code) )
          raise AssertionException.new "Bad response code expected 201, but found: #{response.code}.#{" " + error_message}", response.body
        end
      end

      def assert_response_gone(response)
        unless assertion_bool( [410].include?(response.code) )
          raise AssertionException.new "Bad response code expected 410, but found: #{response.code}", response.body
        end
      end

      def assert_response_not_found(response)
        unless assertion_bool( [404].include?(response.code) )
          raise AssertionException.new "Bad response code expected 404, but found: #{response.code}", response.body
        end
      end

      def assert_response_bad(response)
        unless assertion_bool( [400].include?(response.code) )
          raise AssertionException.new "Bad response code expected 400, but found: #{response.code}", response.body
        end
      end

      def assert_navigation_links(bundle)
        unless assertion_bool( bundle.first_link && bundle.last_link && bundle.next_link )
          raise AssertionException.new "Expecting first, next and last link to be present"
        end
      end

      def assert_bundle_response(response)
        unless assertion_bool( response.resource.class == FHIR::Bundle )
          raise AssertionException.new "Expected FHIR Bundle but found: #{response.resource.class}", response.body
        end
      end
      def assert_bundle_entry_count(response, count)
        unless assertion_bool( response.resource.total == count.to_i )
          raise AssertionException.new "Expected FHIR Bundle with #{count} entries but found: #{response.resource.total} entries", response.body
        end
      end

      def assert_valid_resource_content_type_present(client_reply)
        header = client_reply.response.headers[:content_type]

        content_type = header
        charset = encoding = nil

        content_type = header[0, header.index(';')] if !header.index(';').nil?
        charset = header[header.index(';charset=')+9..-1] if !header.index(';charset=').nil?
        encoding = Encoding.find(charset) if !charset.nil?

        unless assertion_bool( encoding == Encoding::UTF_8 )
          raise AssertionException.new "Response content-type specifies encoding other than UTF-8: #{charset}", header
        end
        unless assertion_bool( (content_type == FHIR::Formats::ResourceFormat::RESOURCE_XML) || (content_type == FHIR::Formats::ResourceFormat::RESOURCE_JSON) )
          raise AssertionException.new "Invalid FHIR content-type: #{content_type}", header
        end
      end

      def assert_last_modified_present(client_reply)
        header = client_reply.response.headers[:last_modified]
        assert assertion_bool( !header.nil? ), 'Last-modified HTTP header is missing.'
      end

      def assert_valid_content_location_present(client_reply)
        header = client_reply.response.headers[:content_location]
        assert assertion_bool( !header.nil? ), 'Content-location HTTP header is missing.'
      end

      def assert_response_code(response, code)
        unless assertion_bool( code == response.code )
          raise AssertionException.new "Bad response code expected #{code}, but found: #{response.code}", response.body
        end
      end

      def assert_resource_type(response, resource_type)
        unless assertion_bool( !response.resource.nil? && response.resource.class == resource_type )
          raise AssertionException.new "Bad response type expected #{resource_type}, but found: #{response.resource.class}", response.body
        end
      end

      def assert_minimum(response, fixture)
        resource_xml = response.try(:resource).try(:to_xml)
        fixture_xml = fixture.try(:to_xml)

        resource_doc = Nokogiri::XML(resource_xml)
        resource_doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')

        fixture_doc = Nokogiri::XML(fixture_xml)
        fixture_doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')

        diffs = []
        fixture_doc.diff(resource_doc, :removed => true){|change, node| diffs << node.to_xml}

        unless assertion_bool( diffs.empty? )
          raise AssertionException.new "Found #{diffs.length} difference(s) between minimum and actual resource.", diffs.to_s
        end
      end

      def assertion_bool(expression)
        if @negated then !expression else expression end
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
