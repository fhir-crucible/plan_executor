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
        @supported_versions = [:stu3]
      end

      def setup
        @attachments = {}
        @mime_types = {}
        @records = {}
        @attachments["pdf"] = 'ccda_pdf.pdf'
        @attachments["structured"] = 'ccda_structured.xml'
        @attachments["unstructured"] = 'ccda_unstructured.xml'

        @mime_types["pdf"] = "application/pdf"
        @mime_types["structured"] = "application/xml"
        @mime_types["unstructured"] = "application/xml"

        @resources = Crucible::Generator::Resources.new(fhir_version)

        patient = @resources.patient_register
        practitioner = @resources.practitioner_register

        create_object(patient, :patient)
        create_object(practitioner, :practitioner)
      end

      def teardown
        @records.each_value do |value|
          @client.destroy(value.class, value.id)
        end
      end

      %w(pdf structured unstructured).each do |att_type|
        test "A13_#{att_type}1", "Submit unsolicited attachment of #{att_type}" do
          comm = FHIR::Communication.new()
          comm.subject = [@records[:patient].to_reference]
          comm.recipient = [@records[:practitioner].to_reference]

          comm_att = FHIR::Attachment.new()
          comm_att.contentType = @mime_types[att_type]
          comm_att.data = base64_encoded(att_type)
          comm_att.title = @attachments[att_type]

          payload = FHIR::Communication::Payload.new
          payload.contentAttachment = [comm_att]

          comm.payload = payload
          create_object(comm, "comm_#{att_type}")
        end

        test "A13_#{att_type}2", "Submit solicited attachment of #{att_type}" do
          # find a suitable CommunicationRequest to respond to
          options = {
            :search => {
              :flag => true,
              :compartment => nil,
              :parameters => {
                _count: 10
              }
            }
          }
          reply = @client.search(FHIR::CommunicationRequest, options)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          comm_req = reply.resource.entry.sample.try(:resource)

          assert comm_req, 'No CommunicationRequest returned from server'

          comm = FHIR::Communication.new()
          comm.subject = [comm_req.subject]
          comm.recipient = [comm_req.sender]
          comm.basedOn = [comm_req.to_reference]

          comm_att = FHIR::Attachment.new()
          comm_att.contentType = @mime_types[att_type]
          comm_att.data = base64_encoded(att_type)
          comm_att.title = @attachments[att_type]

          payload = FHIR::Communication::Payload.new
          payload.contentAttachment = [comm_att]

          comm.payload = payload
          create_object(comm, "comm_#{att_type}")
        end
      end

      private

      def base64_encoded(type)
        Base64.encode64(File.read(File.join(Crucible::Generator::Resources::FIXTURE_DIR, "attachment", "#{@attachments[type]}")))
      end

      def create_object(obj, obj_sym)
        reply = @client.create obj
        assert_response_ok(reply)
        obj.id = reply.id
        @records[obj_sym] = obj

        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_valid_content_location_present(reply) }

        warning { assert @records[obj_sym].equals? reply.resource }
      end

    end
  end
end
