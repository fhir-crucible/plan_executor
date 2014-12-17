module Crucible
  module Tests
    class ReadTest < BaseTest

      def id
        'ReadTest'
      end

      def description
        'Initial Sprinkler tests (R001, R002, R003, R004) for testing basic READ requests.'
      end

      def setup
        @patient = ReadTest.createPatient("Emerald", "Caro")
        reply = @client.create(@patient)
        @id = reply.id
      end

      def teardown
        @client.destroy(FHIR::Patient, @id)
      end

      def self.createPatient(family, given)
        patient = FHIR::Patient.new(name: [FHIR::HumanName.new(family: [family], given: [given])])
      end

      # [SprinklerTest("R001", "Result headers on normal read")]
      test "R001", "get person data" do
        reply = @client.read(FHIR::Patient, @id)
        assert_response_ok(reply)
        assert_equal @id, reply.id, 'Server returned wrong patient.'
        warning { assert_valid_resource_content_type_present(reply) }
        warning { assert_last_modified_present(reply) }
        warning { assert_valid_content_location_present(reply) }
      end
      #     public void GetTestDataPerson()
      #     {
      #         Patient p = NewPatient("Emerald", "Caro");
      #         ResourceEntry<Patient> entry = Client.Create(p, null, false);
      #         string id = entry.GetBasicId();

      #         ResourceEntry<Patient> pat = Client.Read<Patient>(id);

      #         HttpTests.AssertHttpOk(Client);

      #         HttpTests.AssertValidResourceContentTypePresent(Client);
      #         HttpTests.AssertLastModifiedPresent(Client);
      #         HttpTests.AssertContentLocationPresentAndValid(Client);
      #     }

      # [SprinklerTest("R002", "Read unknown resource type")]
      test "R002", "get unknown resource type" do
        skip
      end
      #     public void TryReadUnknownResourceType()
      #     {
      #         ResourceIdentity id = ResourceIdentity.Build(Client.Endpoint, "thisreallywondexist", "1");
      #         HttpTests.AssertFail(Client, () => Client.Read<Patient>(id), HttpStatusCode.NotFound);

      #         // todo: if the Content-Type header was not set by the server, this generates an abstract exception:
      #         // "The given key was not present in the dictionary";
      #     }

      # [SprinklerTest("R003", "Read non-existing resource id")]
      test "R003", "get non existing resource" do
        skip
      end
      #     public void TryReadNonExistingResource()
      #     {
      #         HttpTests.AssertFail(Client, () => Client.Read<Patient>("Patient/3141592unlikely"), HttpStatusCode.NotFound);
      #     }

      # [SprinklerTest("R004", "Read bad formatted resource id")]
      test "R004", "get bad formatted resource id" do
        skip
      end
      #     public void TryReadBadFormattedResourceId()
      #     {
      #         //Test for Spark issue #7, https://github.com/furore-fhir/spark/issues/7
      #         HttpTests.AssertFail(Client, () => Client.Read<Patient>("Patient/ID-may-not-contain-CAPITALS"),
      #             HttpStatusCode.BadRequest);
      #     }
      # }

    end
  end
end