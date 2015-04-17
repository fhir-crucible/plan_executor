
module Crucible
  module Tests
    class FetchPatientRecordTest < BaseSuite

      def id
        'MultiServerFetchPatientRecord001'
      end

      def description
        'Crucible test for transferring a patient record from one server to another'
      end

      def multiserver
        true
      end

      def teardown
        @client2_ids.each do |klass, ids|
          ids.each do |id|
            @client2.destroy(klass.constantize, id)
          end
        end if @client2_ids
      end

      test 'FPR01','Transfer Patient record from server 1 to server 2' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything'
          links 'http://hl7.org/implement/standards/FHIR-Develop/argonauts.html'
          requires resource: "Patient", methods: ["create", "read", "$everything"]
          validates resource: "Patient", methods: ["create", "read", "$everything"]
        }

        client1_patients = @client.read_feed(FHIR::Patient)
        assert_response_ok(client1_patients)

        client1_fetch = @client.fetch_patient_record(client1_patients.resource.entry[0].resource.xmlId)
        assert_response_ok(client1_fetch)
        assert_bundle_response(client1_fetch)

        failures = {}
        written = []
        @client2_ids = {}
        client1_fetch.resource.entry.each do |bundle_entry|
          resource = bundle_entry.resource
          resource.xmlId = nil # drop ids
          reply = @client2.create resource
          @patient_id = reply.id if resource.class == FHIR::Patient
          if assert_response_ok(reply)
            written << resource
            @client2_ids[resource.class.to_s] ||= []
            @client2_ids[resource.class.to_s] << reply.id
          else
            failures[resource.class.to_s] ||= []
            failures[resource.class.to_s] << (resource.xmlId || resource._id.to_s)
          end
        end

        assert failures.values.flatten.empty?, "Failed to write record from server 1 to server 2: #{failures}"

        client2_fetch = @client2.fetch_patient_record(@patient_id)

        assert (client1_fetch.resource.entry - client2_fetch.resource.entry).empty?, "Found differences: #{client1_fetch.resource.entry - client2_fetch.resource.entry}"
      end

      test 'FPR01_A','Transfer Patient record from server 1 to server 2 - without id, text, meta' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything'
          links 'http://hl7.org/implement/standards/FHIR-Develop/argonauts.html'
          requires resource: "Patient", methods: ["create", "read", "$everything"]
          validates resource: "Patient", methods: ["create", "read", "$everything"]
        }

        client1_patients = @client.read_feed(FHIR::Patient)
        assert_response_ok(client1_patients)

        client1_fetch = @client.fetch_patient_record(client1_patients.resource.entry[0].resource.xmlId)
        assert_response_ok(client1_fetch)
        assert_bundle_response(client1_fetch)

        failures = {}
        written = []
        @client2_ids = {}
        client1_resources = {}
        client1_fetch.resource.entry.each do |bundle_entry|
          resource = bundle_entry.resource
          resource.xmlId = nil # drop ids
          resource.text = nil
          resource.meta = nil
          client1_resources[resource.class.to_s] ||= []
          client1_resources[resource.class.to_s] << resource
          reply = @client2.create resource
          @patient_id = reply.id if resource.class == FHIR::Patient
          unless assert_response_ok(reply)
            written << resource
            @client2_ids[resource.class.to_s] ||= []
            @client2_ids[resource.class.to_s] << reply.id
          else
            failures[resource.class.to_s] ||= []
            failures[resource.class.to_s] << (resource.xmlId || resource._id.to_s)
          end
        end

        assert failures.values.flatten.empty?, "Failed to write record from server 1 to server 2: #{failures}"

        client2_fetch = @client2.fetch_patient_record(@patient_id)

        mismatches = {}
        client2_fetch.resource.entry.each do |bundle_entry|
          resource = bundle_entry.resource
          found = false
          if client1_resources.keys.include? resource.class.to_s
            client1_resources[resource.class.to_s].each do |res|
              if resource.equals?(res, ['_id', 'xmlId', 'text', 'meta'])
                found = true
                client1_resources[resource.class.to_s].delete(res)
              end
            end
            mismatches[resource.class.to_s] ||= [] unless found
            mismatches[resource.class.to_s] << (resource.xmlId || resource.try('code').try('text') || resource._id.to_s) unless found
          else
            warning { assert client1_resources.keys.include?(resource.class.to_s), "Additional resource returned from server 2: #{resource.class}" }
          end
        end

        warning { assert mismatches.values.flatten.empty?, "Found additional resource differences in fetched resources from server 2: #{mismatches}."}
        client1_resources.each do |klass,resources|
          client1_resources.delete(klass) if resources.blank?
          resources.map! {|resource| (resource.xmlId || resource.try('code').try('text') || resource._id.to_s)}
        end
        assert client1_resources.values.flatten.empty?, "Missing server 1 resources when fetched from server 2: #{client1_resources}"
      end

      test 'FPR02','Transfer Patient record from server 2 to server 1' do
        metadata {
          links 'http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything'
          links 'http://hl7.org/implement/standards/FHIR-Develop/argonauts.html'
          requires resource: "Patient", methods: ["create", "read", "$everything"]
          validates resource: "Patient", methods: ["create", "read", "$everything"]
        }

        client2_patients = @client2.read_feed(FHIR::Patient)
        assert_response_ok(client2_patients)

        client2_fetch = @client2.fetch_patient_record(client2_patients.resource.entry[0].resource.xmlId)
        assert_response_ok(client2_fetch)
        assert_bundle_response(client2_fetch)

        failures = {}
        written = []
        @client1_ids = {}
        client2_fetch.resource.entry.each do |bundle_entry|
          resource = bundle_entry.resource
          resource.xmlId = nil # drop ids
          reply = @client.create resource
          @patient_id = reply.id if resource.class == FHIR::Patient
          if assert_response_ok(reply)
            written << resource
            @client1_ids[resource.class.to_s] ||= []
            @client1_ids[resource.class.to_s] << reply.id
          else
            failures[resource.class.to_s] ||= []
            failures[resource.class.to_s] << (resource.xmlId || resource._id.to_s)
          end
        end

        assert failures.values.flatten.empty?, "Failed to write record from server 2 to server 1: #{failures}"

        client1_fetch = @client.fetch_patient_record(@patient_id)

        assert (client2_fetch.resource.entry - client1_fetch.resource.entry).empty?, "Found differences: #{client2_fetch.resource.entry - client1_fetch.resource.entry}"
      end

    end
  end
end
