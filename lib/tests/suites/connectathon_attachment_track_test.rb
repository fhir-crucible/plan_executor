module Crucible
  module Tests
    class ConnectathonAttachmentTrackTest < BaseSuite
      require "base64"

      attr_accessor :attachments

      def id
        'ConnectathonAttachmentTrackTest'
      end

      def description
        'Test support for using FHIR-based messaging for exchanging attachments, particularly for claims processing/payer provider interactions.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @tags.append('connectathon')
        @category = {id: 'connectathon', title: 'Connectathon'}
      end

      def setup
        @attachments = {}
        @records = {}
        @attachments["pdf"] = 'fixtures/attachment/ccda_pdf.pdf'
        @attachments["structured"] = 'fixtures/attachment/ccda_structured.xml'
        @attachments["unstructured"] = 'fixtures/attachment/ccda_unstructured.xml'

        @resources = Crucible::Generator::Resources.new

        patient = @resources.load_fixture("patient/patient-register-create.xml")
        practitioner = @resources.load_fixture("practitioner/practitioner-register-create.xml")


        create_object(patient, :patient)
        create_object(practitioner, :practitioner)
      end

      %w(pdf, structured, unstructured).each do |att_type|
        test "A13_#{att_type}1", "Submit attachment of #{att_type}" do
          comm = FHIR::Communication.new()
          comm.subject = @records[:patient].to_reference
          comm.recipient = @records[:practitioner].to_reference
          comm.payload = base64_encoded(att_type)

        end
      end

      private

      def base64_encoded(type)
        Base64.encode64(File.read(@attachments[type]))
      end

      def create_object(obj, obj_sym)
        reply = @client.create obj
        assert_response_ok(reply)
        obj.id = reply.id
        @records[obj_sym] = obj

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end

    end
  end
end
