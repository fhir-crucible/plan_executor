module Crucible
  module Tests
    class Connectathon8EverythingOperatorTest < BaseSuite

      def id
        'Connectathon8Track2'
      end

      def description
        'Connectathon 8 Track 2 Tests: getting a patient with the $everything operator'
      end

      def setup
        @resources = Crucible::Generator::Resources.new
        @patient = @resources.example_patient_record_201
        @condition_1 = @resources.example_patient_record_condition_201
        @condition_2 = @resources.example_patient_record_condition_205
        @diagnosticreport = @resources.example_patient_record_diagnosticreport_201
        @encounter_1 = @resources.example_patient_record_encounter_201
        @encounter_2 = @resources.example_patient_record_encounter_202
        @observation = @resources.example_patient_record_observation_202
        @organization_1 = @resources.example_patient_record_organization_201
        @organization_2 = @resources.example_patient_record_organization_203
        @practitioner = @resources.example_patient_record_practitioner_201
        @procedure = @resources.example_patient_record_procedure_201
        @patient_ids = []
      end

      def teardown
        @client.destroy(FHIR::Condition, @cond1_reply.id) if !@cond1_id.nil?
        @client.destroy(FHIR::Procedure, @prc_reply.id) if !@prc_id.nil?
        @client.destroy(FHIR::Encounter, @enc2_reply.id) if !@enc2_id.nil?
        @client.destroy(FHIR::Encounter, @enc1_reply.id) if !@enc1_id.nil?
        @client.destroy(FHIR::DiagnosticReport, @dr_reply.id) if !@dr_id.nil?
        @client.destroy(FHIR::Observation, @obs_reply.id) if !@obs_id.nil?
        @client.destroy(FHIR::Condition, @cond2_reply.id) if !@cond2_id.nil?
        @client.destroy(FHIR::Patient, @pat_reply.id) if !@pat_id.nil?
        @patient_ids.each do |id|
          @client.destroy(FHIR::Patient, id)
        end
        @client.destroy(FHIR::Practitioner, @prac_reply.id) if !@prac_id.nil?
        @client.destroy(FHIR::Organization, @org2_reply.id) if !@org2_id.nil?
        @client.destroy(FHIR::Organization, @org1_reply.id) if !@org1_id.nil?
      end

      #
      # Test if the general Fetch Patient Record operation is supported
      #
      test 'C8T2_1A', 'Fetch all patient records' do
        metadata {
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Expose_the_.27Fetch_Patient_Record.27_operation_.28Server.29'
          requires resource: 'Patient', methods: ['$everything']
          validates resource: 'Patient', methods: ['$everything']
        }

        reply = @client.fetch_patient_record

        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      #
      # Test if the general Fetch Patient Record operation and start/end parameters are supported
      #
      test 'C8T2_1B', 'Fetch all patient records with [start, end]' do
        metadata {
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Expose_the_.27Fetch_Patient_Record.27_operation_.28Server.29'
          requires resource: 'Patient', methods: ['$everything']
          validates resource: 'Patient', methods: ['$everything']
        }

        reply = @client.fetch_patient_record(nil, "2012-01-01", "2012-12-31")

        assert_response_ok(reply)
        assert_bundle_response(reply)

        skip # TODO: Determine how start/end scope all patient records (e.g., birthdate?)
      end

      #
      # Test if the specific Fetch Patient Record operation is supported
      #
      test 'C8T2_2A', 'Fetch specific patient record' do
        metadata {
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Expose_the_.27Fetch_Patient_Record.27_operation_.28Server.29'
          requires resource: 'Patient', methods: ['create', '$everything']
          validates resource: 'Patient', methods: ['create', '$everything']
        }

        reply = @client.create @patient
        @patient_id = reply.id
        @patient_ids << reply.id
        assert_response_ok(reply)

        record = @client.fetch_patient_record(@patient_id)

        assert_response_ok(record)
        assert_bundle_response(record)

        patient = @patient
        patient.xmlId = @patient_id

        assert patient.equals?(record.resource.entry[0].resource), "Returned patient doesn't match original patient."
      end

      #
      # Test if the specific Fetch Patient Record operation and start/end parameters are supported
      #
      test 'C8T2_2B', 'Fetch specific patient record with [start, end]' do
        metadata {
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Expose_the_.27Fetch_Patient_Record.27_operation_.28Server.29'
          requires resource: 'Patient', methods: ['create', '$everything']
          validates resource: 'Patient', methods: ['create', '$everything']
        }

        reply = @client.create @patient
        @patient_id = reply.id
        @pat_reply = reply
        @patient_ids << reply.id

        assert_response_ok(reply)

        record = @client.fetch_patient_record(@patient_id, "2012-01-01", "2012-12-31")

        assert_response_ok(record)
        assert_bundle_response(record)

        patient = @patient
        patient.xmlId = @patient_id

        assert patient.equals?(record.resource.entry[0].resource), "Returned patient doesn't match original patient."

        # TODO: Determine how start/end scope specific patient records (e.g., birthdate?)
      end

      #
      # Test if we can update parts of a specific Fetch Patient Record operation result
      #
      test 'C8T2_2C', 'Fetch specific patient record - BONUS: Update' do
        metadata {
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_8#2._Expose_the_.27Fetch_Patient_Record.27_operation_.28Server.29'
          requires resource: 'Patient', methods: ['create', 'update', '$everything']
          validates resource: 'Patient', methods: ['create', 'update', '$everything']
        }

        record = @client.fetch_patient_record(@patient_id)

        assert_response_ok(record)
        assert_bundle_response(record)

        @patient.telecom[0].value='1-234-567-8901'
        @patient.name[0].given = ["Not", "Given"]

        reply = @client.update @patient, @patient_id

        assert_response_ok(reply)

        record = @client.fetch_patient_record(@patient_id)

        assert_response_ok(record)
        assert_bundle_response(record)
        assert record.resource.entry[0].resource.telecom[0].value == '1-234-567-8901'
        assert record.resource.entry[0].resource.name[0].given == ['Not', 'Given']
      end

      #
      # Test if we can write and read an entire patient record - exact
      #
      test 'C8T2_3_A', 'Write and then fetch an entire patient record - exact' do
        metadata {
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          links "#{BASE_SPEC_LINK}/argonauts.html"
          requires resource: 'Organization', methods: ['create']
          requires resource: 'Practitioner', methods: ['create']
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Condition', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          requires resource: 'DiagnosticReport', methods: ['create']
          requires resource: 'Encounter', methods: ['create']
          requires resource: 'Procedure', methods: ['create']
          validates resource: 'Patient', methods: ['create', '$everything']
          validates resource: 'Organization', methods: ['create']
          validates resource: 'Practitioner', methods: ['create']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Condition', methods: ['create']
          validates resource: 'Observation', methods: ['create']
          validates resource: 'DiagnosticReport', methods: ['create']
          validates resource: 'Encounter', methods: ['create']
          validates resource: 'Procedure', methods: ['create']
        }

        create_patient_record

        record = @client.fetch_patient_record(@pat_reply.id)

        assert_response_ok(record)
        assert_bundle_response(record)

        @created = true
        mismatches = []
        record.resource.entry.each do |bundle_entry|
          case bundle_entry.resource.class
          when FHIR::Organization
            case bundle_entry.resource.xmlId
            when @org1_id
              mismatches << bundle_entry.resource.mismatch(@organization_1) unless bundle_entry.resource.equals?(@organization_1)
            when @org2_id
              mismatches << bundle_entry.resource.mismatch(@organization_2) unless bundle_entry.resource.equals?(@organization_2)
            end
          when FHIR::Practitioner
            mismatches << bundle_entry.resource.mismatch(@practitioner) unless bundle_entry.resource.equals?(@practitioner)
          when FHIR::Patient
            mismatches << bundle_entry.resource.mismatch(@patient) unless bundle_entry.resource.equals?(@patient)
          when FHIR::Condition
            case bundle_entry.resource.xmlId
            when @cond1_id
              mismatches << bundle_entry.resource.mismatch(@condition_1) unless bundle_entry.resource.equals?(@condition_1)
            when @cond2_id
              mismatches << bundle_entry.resource.mismatch(@condition_2) unless bundle_entry.resource.equals?(@condition_2)
            end
          when FHIR::Observation
            mismatches << bundle_entry.resource.mismatch(@observation) unless bundle_entry.resource.equals?(@observation)
          when FHIR::DiagnosticReport
            mismatches << bundle_entry.resource.mismatch(@diagnosticreport) unless bundle_entry.resource.equals?(@diagnosticreport)
          when FHIR::Encounter
            case bundle_entry.resource.xmlId
            when @enc1_id
              mismatches << bundle_entry.resource.mismatch(@encounter_1) unless bundle_entry.resource.equals?(@encounter_1)
            when @enc2_id
              mismatches << bundle_entry.resource.mismatch(@encounter_2) unless bundle_entry.resource.equals?(@encounter_2)
            end
          when FHIR::Procedure
            mismatches << bundle_entry.resource.mismatch(@procedure) unless bundle_entry.resource.equals?(@procedure)
          end
        end

        assert mismatches.flatten.empty?, "Data returned from the server did not match source data: #{mismatches.flatten}"
      end

      #
      # Test if we can write and read an entire patient record - almost
      #
      test 'C8T2_3_B', 'Fetch an entire patient record - ignore meta & text' do
        metadata {
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          links "#{BASE_SPEC_LINK}/argonauts.html"
          validates resource: 'Patient', methods: ['$everything']
        }

        skip unless @created

        record = @client.fetch_patient_record(@pat_reply.id)

        assert_response_ok(record)
        assert_bundle_response(record)

        mismatches = []
        record.resource.entry.each do |bundle_entry|
          case bundle_entry.resource.class
          when FHIR::Organization
            case bundle_entry.resource.xmlId
            when @org1_id
              mismatches << bundle_entry.resource.mismatch(@organization_1, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@organization_1)
            when @org2_id
              mismatches << bundle_entry.resource.mismatch(@organization_2, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@organization_2)
            end
          when FHIR::Practitioner
            mismatches << bundle_entry.resource.mismatch(@practitioner, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@practitioner)
          when FHIR::Patient
            mismatches << bundle_entry.resource.mismatch(@patient, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@patient)
          when FHIR::Condition
            case bundle_entry.resource.xmlId
            when @cond1_id
              mismatches << bundle_entry.resource.mismatch(@condition_1, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@condition_1)
            when @cond2_id
              mismatches << bundle_entry.resource.mismatch(@condition_2, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@condition_2)
            end
          when FHIR::Observation
            mismatches << bundle_entry.resource.mismatch(@observation, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@observation)
          when FHIR::DiagnosticReport
            mismatches << bundle_entry.resource.mismatch(@diagnosticreport, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@diagnosticreport)
          when FHIR::Encounter
            case bundle_entry.resource.xmlId
            when @enc1_id
              mismatches << bundle_entry.resource.mismatch(@encounter_1, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@encounter_1)
            when @enc2_id
              mismatches << bundle_entry.resource.mismatch(@encounter_2, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@encounter_2)
            end
          when FHIR::Procedure
            mismatches << bundle_entry.resource.mismatch(@procedure, ['_id', 'meta', 'text']) unless bundle_entry.resource.equals?(@procedure)
          end
        end

        assert mismatches.flatten.empty?, "Data returned from the server did not match source data: #{mismatches.flatten}"
      end

      #
      # Test if we can write and read an entire patient record - count
      #
      test 'C8T2_3_C', 'Fetch an entire patient record - count' do
        metadata {
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          links "#{BASE_SPEC_LINK}/argonauts.html"
          validates resource: 'Patient', methods: ['$everything']
        }

        skip unless @created

        record = @client.fetch_patient_record(@pat_reply.id)

        assert_response_ok(record)
        assert_bundle_response(record)

        record.resource.entry.each do |bundle_entry|
          if @ids_count.keys.include?(bundle_entry.resource.class.to_s)
            @ids_count[bundle_entry.resource.class.to_s].delete bundle_entry.resource.xmlId
          else
            warning { assert @ids_count.keys.include?(bundle_entry.resource.class.to_s),
              "Found additional resource(s) in $everything Bundle: #{bundle_entry.resource.class}#{ "-#{bundle_entry.resource.code.text}" if bundle_entry.resource.class == FHIR::List}" }
          end
        end

        @ids_count.each {|klass,ids| @ids_count.delete(klass) if ids.blank?}
        assert @ids_count.flatten.empty?, "Returned Bundle is missing resources: #{@ids_count}"
      end

      def create_patient_record
        @ids_count = {
          'FHIR::Organization' => [],
          'FHIR::Practitioner' => [],
          'FHIR::Patient' => [],
          'FHIR::Condition' => [],
          'FHIR::Observation' => [],
          'FHIR::DiagnosticReport' => [],
          'FHIR::Encounter' => [],
          'FHIR::Procedure' => []
        }

        @org1_reply = @client.create @organization_1
        @org1_id = @org1_reply.id
        @organization_1.xmlId = @org1_id
        @ids_count[FHIR::Organization.to_s] << @org1_id
        assert_response_ok(@org1_reply)

        @org2_reply = @client.create @organization_2
        @org2_id = @org2_reply.id
        @organization_2.xmlId = @org2_id
        @ids_count[FHIR::Organization.to_s] << @org2_id
        assert_response_ok(@org2_reply)

        @practitioner.practitionerRole[0].managingOrganization.reference = "Organization/#{@org1_id}"
        @prac_reply = @client.create @practitioner
        @prac_id = @prac_reply.id
        @practitioner.xmlId = @prac_id
        @ids_count[FHIR::Practitioner.to_s] << @prac_id
        assert_response_ok(@prac_reply)

        @patient.managingOrganization.reference = "Organization/#{@org1_id}"
        @pat_reply = @client.create @patient
        @pat_id = @pat_reply.id
        @patient.xmlId = @pat_id
        @ids_count[FHIR::Patient.to_s] << @pat_id
        assert_response_ok(@pat_reply)

        @condition_2.patient.reference = "Patient/#{@pat_id}"
        @condition_2.asserter.reference = "Practitioner/#{@prac_id}"
        @cond2_reply = @client.create @condition_2
        @cond2_id = @cond2_reply.id
        @condition_2.xmlId = @cond2_id
        @ids_count[FHIR::Condition.to_s] << @cond2_id
        assert_response_ok(@cond2_reply)

        @observation.subject.reference = "Patient/#{@pat_id}"
        @observation.performer[0].reference = "Practitioner/#{@prac_id}"
        @obs_reply = @client.create @observation
        @obs_id = @obs_reply.id
        @observation.xmlId = @obs_id
        @ids_count[FHIR::Observation.to_s] << @obs_id
        assert_response_ok(@obs_reply)

        @diagnosticreport.subject.reference = "Patient/#{@pat_id}"
        @diagnosticreport.performer.reference = "Organization/#{@org2_id}"
        @dr_reply = @client.create @diagnosticreport
        @dr_id = @dr_reply.id
        @diagnosticreport.xmlId = @dr_id
        @ids_count[FHIR::DiagnosticReport.to_s] << @dr_id
        assert_response_ok(@dr_reply)

        @encounter_1.patient.reference = "Patient/#{@pat_id}"
        @encounter_1.participant[0].individual.reference = "Practitioner/#{@prac_id}"
        @encounter_1.serviceProvider.reference = "Organization/#{@org1_id}"
        @enc1_reply = @client.create @encounter_1
        @enc1_id = @enc1_reply.id
        @encounter_1.xmlId = @enc1_id
        @ids_count[FHIR::Encounter.to_s] << @enc1_id
        assert_response_ok(@enc1_reply)

        @encounter_2.patient.reference = "Patient/#{@pat_id}"
        @encounter_2.participant[0].individual.reference = "Practitioner/#{@prac_id}"
        @encounter_2.serviceProvider.reference = "Organization/#{@org1_id}"
        @enc2_reply = @client.create @encounter_2
        @enc2_id = @enc2_reply.id
        @encounter_2.xmlId = @enc2_id
        @ids_count[FHIR::Encounter.to_s] << @enc2_id
        assert_response_ok(@enc2_reply)

        @procedure.patient.reference = "Patient/#{@pat_id}"
        @procedure.indication[0].text = "DiagnosticReport/#{@dr_id}"
        @procedure.performer[0].person.reference = "Practitioner/#{@prac_id}"
        @procedure.encounter.reference = "Encounter/#{@enc2_id}"
        @prc_reply = @client.create @procedure
        @prc_id = @prc_reply.id
        @procedure.xmlId = @prc_id
        @ids_count[FHIR::Procedure.to_s] << @prc_id
        assert_response_ok(@prc_reply)

        @encounter_2.indication[0].reference = "Procedure/#{@prc_id}"
        @enc2_reply = @client.update @encounter_2, @enc2_id
        assert_response_ok(@enc2_reply)

        @condition_1.patient.reference = "Patient/#{@pat_id}"
        @condition_1.encounter.reference = "Encounter/#{@enc1_id}"
        @condition_1.asserter.reference = "Practitioner/#{@prac_id}"
        @condition_1.evidence[0].detail[0].reference = "Observation/#{@obs_id}"
        @condition_1.dueTo[0].target.reference = "Procedure/#{@prc_id}"
        @condition_1.dueTo[1].target.reference = "Condition/#{@cond2_id}"
        @cond1_reply = @client.create @condition_1
        @cond1_id = @cond1_reply.id
        @condition_1.xmlId = @cond1_id
        @ids_count[FHIR::Condition.to_s] << @cond1_id
        assert_response_ok(@cond1_reply)
      end

    end
  end
end
