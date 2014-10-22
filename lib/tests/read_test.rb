module Crucible
  module Tests
    class ReadTest < BaseTest

      def id
        'A001'
      end

      def description
        'Initial Sprinkler tests (R001, R002, R003, R004) for testing basic READ requests.'
      end

      def self.createPatient(family, given)
        patient = FHIR::Patient.new(name: [FHIR::HumanName.new(family: [family], given: [given])])
      end

      # [SprinklerTest("R001", "Result headers on normal read")]
      def r001_get_person_data_test
        patient = ReadTest.createPatient("Emerald", "Caro")
        x = @client.create(patient)
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
      def r002_get_unknown_resource_type_test
        raise 'Implementation missing: r002_get_unknown_resource_type_test'
      end
      #     public void TryReadUnknownResourceType()
      #     {
      #         ResourceIdentity id = ResourceIdentity.Build(Client.Endpoint, "thisreallywondexist", "1");
      #         HttpTests.AssertFail(Client, () => Client.Read<Patient>(id), HttpStatusCode.NotFound);

      #         // todo: if the Content-Type header was not set by the server, this generates an abstract exception:
      #         // "The given key was not present in the dictionary";
      #     }

      # [SprinklerTest("R003", "Read non-existing resource id")]
      def r003_get_non_existing_resource_test
        raise 'Implementation missing: r003_get_non_existing_resource_test'
      end
      #     public void TryReadNonExistingResource()
      #     {
      #         HttpTests.AssertFail(Client, () => Client.Read<Patient>("Patient/3141592unlikely"), HttpStatusCode.NotFound);
      #     }

      # [SprinklerTest("R004", "Read bad formatted resource id")]
      def r004_get_bad_formatted_resource_id_test
        raise 'Implementation missing: r004_get_bad_formatted_resource_id_test'
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