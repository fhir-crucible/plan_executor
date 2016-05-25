module Crucible
  module Tests
    class ConnectathonPatchTrackTest < BaseSuite

      def id
        'ConnectathonPatchTrackTest'
      end

      def description
        'Connectathon PATCH Test.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'connectathon', title: 'Connectathon'}
      end

      def setup
        @medication_order = Crucible::Generator::Resources.new.medicationorder_simple
        @medication_order.id = nil # clear the identifier, in case the server checks for duplicates
        @medication_order.identifier = nil # clear the identifier, in case the server checks for duplicates

        reply = @client.create(@medication_order)

        assert_response_ok(reply)
        @medication_order_id = reply.id

      end

      def teardown
        @client.destroy(FHIR::MedicationOrder, @medication_order_id) unless @medication_order_id.nil?
      end

      ['JSON','XML'].each do |fmt|

        #
        # Get the MedicationOrder that was just created.
        #
        test "C12PATCH_1_(#{fmt})","Get Existing MedicationOrder by #{fmt}" do
          metadata {
            links "#{REST_SPEC_LINK}#read"
            links "#{BASE_SPEC_LINK}/medicationorder.html"
            links 'http://wiki.hl7.org/index.php?title=201605_PATCH_Connectathon_Track_Proposal'
            requires resource: 'MedicationOrder', methods: ['read']
            validates resource: 'MedicationOrder', methods: ['read']
          }
          
          reply = @client.read(FHIR::MedicationOrder, @medication_order_id, resource_format(fmt))
          assert_response_ok(reply)
          assert_resource_type(reply, FHIR::MedicationOrder)
          assert_resource_content_type(reply, fmt.downcase)
          warning { 
            assert(!reply.resource.meta.nil?, 'Last Updated and VersionId not present.')
            assert(!reply.resource.meta.versionId.nil?, 'VersionId not present.')
            @previous_version_id = reply.resource.meta.versionId
            assert(!reply.resource.meta.lastUpdated.nil?, 'Last Updated not present.')
          }
          
        end


        #
        # Patch the MedicationOrder.
        #
        test "C12PATCH_2_(#{fmt})","#{fmt} Patch Existing MedicationOrder" do
          metadata {
            links "#{REST_SPEC_LINK}#patch"
            links 'http://wiki.hl7.org/index.php?title=201605_PATCH_Connectathon_Track_Proposal'
            requires resource: 'MedicationOrder', methods: ['read']
            validates resource: 'MedicationOrder', methods: ['read']
          }

          patchset = [{ op: "replace", path: "MedicationOrder/status", value: "completed" }]
          reply = @client.partial_update(FHIR::MedicationOrder, @medication_order_id, patchset, {}, resource_format(fmt))

          assert_response_ok(reply)
          assert_resource_type(reply, FHIR::MedicationOrder)
          assert_resource_content_type(reply, fmt.downcase)

          reply = @client.read(FHIR::MedicationOrder, @medication_order_id, resource_format(fmt))
          assert_response_ok(reply)
          assert_equal(reply.resource.status, 'completed', 'Status not updated from patch.')
          warning {
            assert(reply.resource.meta.versionId != @previous_version_id, 'VersionId not updated after patch.') unless @previous_version_id.nil?
          }

        end

        #
        # Attempt to PATCH the MedicationOrder with an old Version Id.
        #
        test "C12PATCH_3_(#{fmt})","#{fmt} Patching Medication Order with old Version Id should result in error" do
          metadata {
            links "#{REST_SPEC_LINK}#patch"
            links 'http://wiki.hl7.org/index.php?title=201605_PATCH_Connectathon_Track_Proposal'
            requires resource: 'MedicationOrder', methods: ['read']
            validates resource: 'MedicationOrder', methods: ['read']
          }

          skip if @previous_version_id.nil?

          patchset = [{ op: "replace", path: "MedicationOrder/status", value: "active" }]

          options = { 'If-Match' => @previous_version_id }
          reply = @client.partial_update(FHIR::MedicationOrder, @medication_order_id, patchset, options, resource_format(fmt))

          assert_response_conflict(reply)

          reply = @client.read(FHIR::MedicationOrder, @medication_order_id, resource_format(fmt))
          assert_response_ok(reply)
          assert_equal(reply.resource.status, 'completed', 'Resource should not have been patched because version id was stale.')

        end

      end

      def resource_format(f)
        "FHIR::Formats::ResourceFormat::RESOURCE_#{f}".constantize
      end

    end
  end
end
