module Crucible
  module Tests
    class TransactionAndBatchTest < BaseSuite

      def id
        'TransactionAndBatchTest'
      end

      def description
        'Test server support for transactions and batch processing including conditional logic.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      def setup
        # nothing
      end

      def teardown
        # delete resources
        @client.destroy(FHIR::Observation, @obs4.id) if @obs4 && !@obs4.id.nil?
        @client.destroy(FHIR::Observation, @obs3.id) if @obs3 && !@obs3.id.nil?
        @client.destroy(FHIR::Observation, @obs2.id) if @obs2 && !@obs2.id.nil?
        @client.destroy(FHIR::Observation, @obs1.id) if @obs1 && !@obs1.id.nil?
        @client.destroy(FHIR::Observation, @obs0a.id) if @obs0a && !@obs0a.id.nil?
        @client.destroy(FHIR::Observation, @obs0b.id) if @obs0b && !@obs0b.id.nil?
        @client.destroy(FHIR::Condition, @condition0.id) if @condition0 && !@condition0.id.nil?
        @client.destroy(FHIR::Condition, @conditionId) if @conditionId
        @client.destroy(FHIR::Patient, @patient0.id) if @patient0 && !@patient0.id.nil?
        @client.destroy(FHIR::Patient, @patient1.id) if @patient1 && !@patient1.id.nil?
        @client.destroy(FHIR::Patient, @badPatientId) if @badPatientId
        @transferIds.each do |klass,list|
          list.each do |id|
            @client.destroy(klass, id) if(!id.nil? && !id.strip.empty?)
          end
        end unless @transferIds.nil?
        @client.destroy(FHIR::Observation, @batch_obs.id) if @batch_obs && !@batch_obs.id.nil?
        @client.destroy(FHIR::Patient, @batch_patient.id) if @batch_patient && !@batch_patient.id.nil?
        @client.destroy(FHIR::Observation, @batch_obs_2.id) if @batch_obs_2 && !@batch_obs_2.id.nil?
        @client.destroy(FHIR::Observation, @batch_obs_3.id) if @batch_obs_3 && !@batch_obs_3.id.nil?
        @client.destroy(FHIR::Patient, @batch_patient_2.id) if @batch_patient_2 && !@batch_patient_2.id.nil?
        @client.destroy(FHIR::Observation, @obs0a_B.id) if @obs0a_B && !@obs0a_B.id.nil?
        @client.destroy(FHIR::Observation, @obs0b_B.id) if @obs0b_B && !@obs0b_B.id.nil?
        @client.destroy(FHIR::Condition, @condition0_B.id) if @condition0_B && !@condition0_B.id.nil?
        @client.destroy(FHIR::Patient, @patient0_B.id) if @patient0_B && !@patient0_B.id.nil?
      end

      # Create a Patient Record as a transaction
      test 'XFER0','Create a Patient Record as Transaction' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/observation.html"
          links "#{BASE_SPEC_LINK}/condition.html"
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          requires resource: 'Condition', methods: ['create']
          requires resource: nil, methods: ['transaction-system']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Observation', methods: ['create']
          validates resource: 'Condition', methods: ['create']
          validates resource: nil, methods: ['transaction-system']
        }

        @patient0 = ResourceGenerator.minimal_patient("#{Time.now.to_i}",'Transaction')
        @patient0.id = 'foo' # assign an id so related resources can reference the patient
        # height
        @obs0a = ResourceGenerator.minimal_observation('http://loinc.org','8302-2',170,'cm',@patient0.id)
        # weight
        @obs0b = ResourceGenerator.minimal_observation('http://loinc.org','3141-9',200,'kg',@patient0.id)
        # obesity
        @condition0 = ResourceGenerator.minimal_condition('http://snomed.info/sct','414915002',@patient0.id)

        @client.begin_transaction
        @client.add_transaction_request('POST',nil,@patient0)
        @client.add_transaction_request('POST',nil,@obs0a)
        @client.add_transaction_request('POST',nil,@obs0b)
        @client.add_transaction_request('POST',nil,@condition0)
        reply = @client.end_transaction

        # set the patient id as nil, until we know that the transaction was successful, so teardown doesn't try
        # to delete something that wasn't created
        @patient0.id = nil

        assert( ((200..299).include?(reply.code)), "Unexpected status code: #{reply.code}" )
        warning{ assert_response_ok(reply) }
        assert_bundle_response(reply)
        assert_bundle_transactions_okay(reply)
        @created_patient_record = true

        # set the IDs to whatever the server created
        @patient0.id = FHIR::ResourceAddress.pull_out_id('Patient',reply.resource.entry[0].try(:response).try(:location))
        @patient0.id = reply.resource.entry[0].try(:resource).try(:xmlId) if @patient0.id.nil?

        @obs0a.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[1].try(:response).try(:location))
        @obs0a.id = reply.resource.entry[1].try(:resource).try(:xmlId) if @obs0a.id.nil?

        @obs0b.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[2].try(:response).try(:location))
        @obs0b.id = reply.resource.entry[2].try(:resource).try(:xmlId) if @obs0b.id.nil?

        @condition0.id = FHIR::ResourceAddress.pull_out_id('Condition',reply.resource.entry[3].try(:response).try(:location))
        @condition0.id = reply.resource.entry[3].try(:resource).try(:xmlId) if @condition0.id.nil?

        # check that the Observations and Condition reference the correct Patient.id
        assert( (reply.resource.entry[1].resource.subject.reference.ends_with?(@patient0.id) rescue false), "Observation doesn't correctly reference Patient/#{@patient0.id}")
        assert( (reply.resource.entry[2].resource.subject.reference.ends_with?(@patient0.id) rescue false), "Observation doesn't correctly reference Patient/#{@patient0.id}")
        assert( (reply.resource.entry[3].resource.patient.reference.ends_with?(@patient0.id) rescue false), "Condition doesn't correctly reference Patient/#{@patient0.id}")
      end

      #  Create a Patient record that uses Bundle.entry.fullUrl to link/reference, rather than Bundle.entry.resource.id
      test 'XFER0B','Create a Patient Record as Transaction (with references using fullUrl rather than IDs)' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/observation.html"
          links "#{BASE_SPEC_LINK}/condition.html"
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          requires resource: 'Condition', methods: ['create']
          requires resource: nil, methods: ['transaction-system']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Observation', methods: ['create']
          validates resource: 'Condition', methods: ['create']
          validates resource: nil, methods: ['transaction-system']
        }

        @patient0_B = ResourceGenerator.minimal_patient("#{Time.now.to_i}",'Transaction')
        patient0_B_id = SecureRandom.uuid
        patient0_B_uri = "urn:uuid:#{patient0_B_id}"

        # height
        @obs0a_B = ResourceGenerator.minimal_observation('http://loinc.org','8302-2',170,'cm',patient0_B_id)
        # weight
        @obs0b_B = ResourceGenerator.minimal_observation('http://loinc.org','3141-9',200,'kg',patient0_B_id)
        # obesity
        @condition0_B = ResourceGenerator.minimal_condition('http://snomed.info/sct','414915002',patient0_B_id)

        @client.begin_transaction
        @client.add_transaction_request('POST',nil,@patient0_B)
        @client.transaction_bundle.entry.first.fullUrl = patient0_B_id
        @client.add_transaction_request('POST',nil,@obs0a_B)
        @client.add_transaction_request('POST',nil,@obs0b_B)
        @client.add_transaction_request('POST',nil,@condition0_B)
        reply = @client.end_transaction

        assert( ((200..299).include?(reply.code)), "Unexpected status code: #{reply.code}" )
        warning{ assert_response_ok(reply) }
        assert_bundle_response(reply)
        assert_bundle_transactions_okay(reply)

        # set the IDs to whatever the server created
        @patient0_B.id = FHIR::ResourceAddress.pull_out_id('Patient',reply.resource.entry[0].try(:response).try(:location))
        @patient0_B.id = reply.resource.entry[0].try(:resource).try(:xmlId) if @patient0_B.id.nil?

        @obs0a_B.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[1].try(:response).try(:location))
        @obs0a_B.id = reply.resource.entry[1].try(:resource).try(:xmlId) if @obs0a_B.id.nil?

        @obs0b_B.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[2].try(:response).try(:location))
        @obs0b_B.id = reply.resource.entry[2].try(:resource).try(:xmlId) if @obs0b_B.id.nil?

        @condition0_B.id = FHIR::ResourceAddress.pull_out_id('Condition',reply.resource.entry[3].try(:response).try(:location))
        @condition0_B.id = reply.resource.entry[3].try(:resource).try(:xmlId) if @condition0_B.id.nil?

        # check that the Observations and Condition reference the correct Patient.id
        assert( (reply.resource.entry[1].resource.subject.reference.ends_with?(@patient0_B.id) rescue false), "Observation doesn't correctly reference Patient/#{@patient0_B.id}")
        assert( (reply.resource.entry[2].resource.subject.reference.ends_with?(@patient0_B.id) rescue false), "Observation doesn't correctly reference Patient/#{@patient0_B.id}")
        assert( (reply.resource.entry[3].resource.patient.reference.ends_with?(@patient0_B.id) rescue false), "Condition doesn't correctly reference Patient/#{@patient0_B.id}")
      end

      # Update a Patient Record as a transaction
      # Conditional create patient
      # Conditional create/update observations
      test 'XFER1','Conditionally Create Patient and add new Observation as Transaction' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/observation.html"
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          requires resource: nil, methods: ['transaction-system']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Observation', methods: ['create']
          validates resource: nil, methods: ['transaction-system']
        }
        skip unless @created_patient_record

        # patient has gained weight
        @obs1 = ResourceGenerator.minimal_observation('http://loinc.org','3141-9',250,'kg',@patient0.id)

        @client.begin_transaction
        @client.add_transaction_request('POST',nil,@patient0,"identifier=#{@patient0.identifier.first.system}|#{@patient0.identifier.first.value}")
        @client.add_transaction_request('POST',nil,@obs1)
        reply = @client.end_transaction

        assert( ((200..299).include?(reply.code)), "Unexpected status code: #{reply.code}" )
        warning{ assert_response_ok(reply) }
        assert_bundle_response(reply)
        assert_bundle_transactions_okay(reply)

        # set the IDs to whatever the server created
        # @patient0.id = FHIR::ResourceAddress.pull_out_id('Patient',reply.resource.entry[0].try(:response).try(:location))
        @obs1.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[1].try(:response).try(:location))
        @obs1.id = reply.resource.entry[1].try(:resource).try(:xmlId) if @obs1.id.nil?
      end

      # Conditionally Update entire patient record
      #   - Patient grew taller, lost weight, obesity is refuted
      #   - Condition ETag plus ?patient=Patient/foo&code=http://snomed.info/sct|414915002
      test 'XFER2','Delete and Create Observation and Conditionally Update Condition as Transaction' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/observation.html"
          links "#{BASE_SPEC_LINK}/condition.html"
          requires resource: 'Observation', methods: ['create','delete']
          requires resource: 'Condition', methods: ['update']
          requires resource: nil, methods: ['transaction-system']
          validates resource: 'Observation', methods: ['create','delete']
          validates resource: 'Condition', methods: ['update']
          validates resource: nil, methods: ['transaction-system']
        }
        skip unless @created_patient_record

        # weight
        @obs2 = ResourceGenerator.minimal_observation('http://loinc.org','3141-9',100,'kg',@patient0.id)
        # obesity has been refuted
        @condition0.patient.reference = "Patient/#{@patient0.id}"
        @condition0.clinicalStatus = 'resolved'
        @condition0.verificationStatus = 'refuted'
        @condition0.abatementBoolean = true

        @client.begin_transaction
        @client.add_transaction_request('DELETE',"Observation/#{@obs0b.id}") if @obs0b && !@obs0b.id.nil? # delete first weight
        @client.add_transaction_request('DELETE',"Observation/#{@obs1.id}") if @obs1 && !@obs1.id.nil? # delete second weight
        @client.add_transaction_request('POST',nil,@obs2) # create new weight observation
        @client.add_transaction_request('PUT',"Condition?code=#{@condition0.code.coding.first.system}|#{@condition0.code.coding.first.code}&patient=Patient/#{@patient0.id}",@condition0)
        reply = @client.end_transaction

        assert( ((200..299).include?(reply.code)), "Unexpected status code: #{reply.code}" )
        warning{ assert_response_ok(reply) }
        assert_bundle_response(reply)
        assert_bundle_transactions_okay(reply)

        # set the IDs to whatever the server created
        @obs2.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[-2].try(:response).try(:location))
        @obs2.id = reply.resource.entry[-2].try(:resource).try(:xmlId) if @obs2.id.nil?

        @conditionId = FHIR::ResourceAddress.pull_out_id('Condition',reply.resource.entry[-1].try(:response).try(:location))
        @conditionId = reply.resource.entry[-1].try(:resource).try(:xmlId) if @conditionId.nil?
      end

      # Create Patients with same identifier, THEN conditionally create patient as part of transaction -- transaction should fail with OperationOutcome
      test 'XFER3','Bad Transaction to Conditionally Create Patient with multiple matches' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/patient.html"
          requires resource: 'Patient', methods: ['create']
          requires resource: nil, methods: ['transaction-system']
          validates resource: 'Patient', methods: ['create']
          validates resource: nil, methods: ['transaction-system']
        }
        skip unless @created_patient_record

        @patient1 = ResourceGenerator.minimal_patient(@patient0.identifier.first.value,@patient0.name.first.given.first)
        reply = @client.create @patient1
        assert_response_ok(reply)
        @patient1.id = (reply.resource.try(:xmlId) || reply.id)

        @client.begin_transaction
        @client.add_transaction_request('POST',nil,@patient1,"identifier=#{@patient0.identifier.first.system}|#{@patient0.identifier.first.value}")
        reply = @client.end_transaction

        # These IDs should not exist, but if they do, then we should delete this Patient during teardown.
        if reply.resource.is_a?(FHIR::Bundle)
          @badPatientId = FHIR::ResourceAddress.pull_out_id('Patient',reply.resource.entry[0].try(:response).try(:location))
          @badPatientId = reply.resource.entry[0].try(:resource).try(:xmlId) if @badPatientId.nil?
        end

        assert((reply.code >= 400 && reply.code < 500), "Failed Transactions should return an HTTP 400 range response, found: #{reply.code}.", reply.body)
        assert_resource_type(reply,FHIR::OperationOutcome)
      end

      # Test Transaction Processing ordering: DELETE, POST, PUT, GET
      test 'XFER4','Transaction Processing Order of Operations' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/observation.html"
          requires resource: 'Observation', methods: ['create','read','delete']
          requires resource: nil, methods: ['transaction-system']
          validates resource: 'Observation', methods: ['create','read','delete']
          validates resource: nil, methods: ['transaction-system']
        }
        skip unless @created_patient_record

        # height observation
        @obs3 = ResourceGenerator.minimal_observation('http://loinc.org','8302-2',177,'cm',@patient0.id)
        # weight observation
        @obs4 = ResourceGenerator.minimal_observation('http://loinc.org','3141-9',105,'kg',@patient0.id)
        # give this *weight* observation the ID of the *height* observation created in XFER1
        @obs4.id = @obs0a.id

        @client.begin_transaction
        # read the all the Patient's weight observations. This should happen last (fourth) and return 1 result.
        @client.add_transaction_request('GET',"Observation?code=#{@obs0b.code.coding.first.system}|#{@obs0b.code.coding.first.code}&patient=Patient/#{@patient0.id}")
        # update the old height observation to be a weight... this should happen third.
        @client.add_transaction_request('PUT',"Observation/#{@obs4.id}",@obs4)
        # create a new height observation... this should happen second.
        @client.add_transaction_request('POST',nil,@obs3)
        # delete the Patient's existing weight observation... this should happen first.
        @client.add_transaction_request('DELETE',"Observation/#{@obs2.id}") if @obs2 && !@obs2.id.nil?
        reply = @client.end_transaction

        assert( ((200..299).include?(reply.code)), "Unexpected status code: #{reply.code}" )
        warning{ assert_response_ok(reply) }
        assert_bundle_response(reply)
        assert_bundle_transactions_okay(reply)

        count = (reply.resource.entry.first.resource.total rescue 0)
        assert(count==1,"In a transaction, GET should execute last and in this case only return 1 result; found #{count}",reply.body)
        searchResultId = (reply.resource.entry.first.resource.entry.first.resource.id rescue nil)
        assert(searchResultId==@obs2.id,"The GET search returned the wrong result. Expected Observation/#{@obs2.id} but found Observation/#{searchResultId}.",reply.body)

        # set the IDs to whatever the server created
        @obs3.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[2].try(:response).try(:location))
        @obs3.id = reply.resource.entry[2].try(:resource).try(:xmlId) if @obs3.id.nil?

        @obs4.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[1].try(:response).try(:location))
        @obs4.id = reply.resource.entry[1].try(:resource).try(:xmlId) if @obs4.id.nil?
      end

      # If $everything operation, fetch patient record, and then use that bundle to update the record in a transaction
      test 'XFER5','Fetch patient record and then present the record as an update transaction' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{REST_SPEC_LINK}#other-bundles"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/patient-operations.html#everything"
          requires resource: 'Patient', methods: ['$everything']
          requires resource: nil, methods: ['transaction-system']
          validates resource: 'Patient', methods: ['$everything']
          validates resource: nil, methods: ['transaction-system']
        }
        skip unless @created_patient_record

        reply = @client.fetch_patient_record(@patient0.id, nil, nil, 'GET')
        assert_response_ok(reply)
        assert_bundle_response(reply)

        everything = reply.resource

        @client.begin_transaction
        @client.transaction_bundle = reply.resource
        reply = @client.end_transaction

        assert( ((200..299).include?(reply.code)), "Unexpected status code: #{reply.code}" )
        warning{ assert_response_ok(reply) }
        assert_bundle_response(reply)
        assert_bundle_transactions_okay(reply)

        # get the new IDs
        @transferPatientId = nil
        @transferIds = {}
        reply.resource.entry.each do |entry|
          klass = entry.resource.class
          entry_id = FHIR::ResourceAddress.pull_out_id(klass.name.demodulize, entry.try(:response).try(:location))
          entry_id = entry.resource.id if entry_id.nil?
          @transferIds[klass] = [] if @transferIds[klass].nil?
          @transferIds[klass] << entry_id
          @transferPatientId = entry_id if(entry.resource.class == FHIR::Patient)
        end

        # check that the IDs and references were rewritten
        everything.entry.each_with_index do |entry,index|
          klass_name = entry.resource.class.name.demodulize
          original_id = entry.resource.id
          transfer_location = (reply.resource.entry[index].response.location rescue nil)
          transfer_id = FHIR::ResourceAddress.pull_out_id( klass_name, transfer_location) if !transfer_location.nil?
          transfer_id = (reply.resource.entry[index].resource.id rescue nil) if transfer_id.nil?
          assert((original_id != transfer_id), "Resource ID was not rewritten: #{original_id}")

          # if class is Observation check subject
          assert( (reply.resource.entry[index].resource.subject==@transferPatientId), "Observation.subject Patient reference was not rewritten." ) if reply.resource.entry[index].resource.class==FHIR::Observation
          # if class is Condition check patient
          assert( (reply.resource.entry[index].resource.patient==@transferPatientId), "Condition.patient reference was not rewritten." ) if reply.resource.entry[index].resource.class==FHIR::Condition
        end
      end

      # delete entire patient record
      test 'XFER6','Delete an Unordered Patient Record as Transaction' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/observation.html"
          links "#{BASE_SPEC_LINK}/condition.html"
          requires resource: 'Patient', methods: ['delete']
          requires resource: 'Observation', methods: ['delete']
          requires resource: 'Condition', methods: ['delete']
          requires resource: nil, methods: ['transaction-system']
          validates resource: 'Patient', methods: ['delete']
          validates resource: 'Observation', methods: ['delete']
          validates resource: 'Condition', methods: ['delete']
          validates resource: nil, methods: ['transaction-system']
        }
        skip unless @created_patient_record

        @client.begin_transaction
        @client.add_transaction_request('DELETE', "Patient/#{@patient0.id}") if @patient0 && !@patient0.id.nil?
        @client.add_transaction_request('DELETE', "Condition/#{@condition0.id}") if @condition0 && !@condition0.id.nil?
        @client.add_transaction_request('DELETE', "Condition/#{@conditionId}") if @conditionId
        @client.add_transaction_request('DELETE', "Observation/#{@obs4.id}") if @obs4 && !@obs4.id.nil?
        @client.add_transaction_request('DELETE', "Observation/#{@obs3.id}") if @obs3 && !@obs3.id.nil?
        @client.add_transaction_request('DELETE', "Observation/#{@obs0a.id}") if @obs0a && !@obs0a.id.nil?
        reply = @client.end_transaction

        assert( ((200..299).include?(reply.code)), "Unexpected status code: #{reply.code}" )
        warning{ assert_response_ok(reply) }
        assert_bundle_response(reply)
        assert_bundle_transactions_okay(reply)
      end

      # delete entire patient record
      test 'XFER7','Delete an Ordered Patient Record as Transaction' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/observation.html"
          links "#{BASE_SPEC_LINK}/condition.html"
          requires resource: 'Patient', methods: ['delete']
          requires resource: 'Observation', methods: ['delete']
          requires resource: 'Condition', methods: ['delete']
          requires resource: nil, methods: ['transaction-system']
          validates resource: 'Patient', methods: ['delete']
          validates resource: 'Observation', methods: ['delete']
          validates resource: 'Condition', methods: ['delete']
          validates resource: nil, methods: ['transaction-system']
        }
        skip unless @created_patient_record

        @client.begin_transaction
        @client.add_transaction_request('DELETE', "Observation/#{@obs4.id}") if @obs4 && !@obs4.id.nil?
        @client.add_transaction_request('DELETE', "Observation/#{@obs3.id}") if @obs3 && !@obs3.id.nil?
        @client.add_transaction_request('DELETE', "Observation/#{@obs0a.id}") if @obs0a && !@obs0a.id.nil?
        @client.add_transaction_request('DELETE', "Condition/#{@condition0.id}") if @condition0 && !@condition0.id.nil?
        @client.add_transaction_request('DELETE', "Condition/#{@conditionId}") if @conditionId
        @client.add_transaction_request('DELETE', "Patient/#{@patient0.id}") if @patient0 && !@patient0.id.nil?
        reply = @client.end_transaction

        assert( ((200..299).include?(reply.code)), "Unexpected status code: #{reply.code}" )
        warning{ assert_response_ok(reply) }
        assert_bundle_response(reply)
        assert_bundle_transactions_okay(reply)
      end

      # For a batch, there SHALL be no interdependencies between the different entries in the Bundle.
      # Batch process entire patient record
      test 'XFER10','Invalid Batch with Interdependencies' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/observation.html"
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Observation', methods: ['create']
          requires resource: nil, methods: ['batch-system']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Observation', methods: ['create']
          validates resource: nil, methods: ['batch-system']
        }

        @batch_patient = ResourceGenerator.minimal_patient("#{Time.now.to_i}",'Batch')
        @batch_patient.id = 'batchfoo' # assign an id so related resources can reference the patient
        # height
        @batch_obs = ResourceGenerator.minimal_observation('http://loinc.org','8302-2',900,'cm',@batch_patient.id)

        @client.begin_batch
        @client.add_batch_request('POST',nil,@batch_patient)
        @client.add_batch_request('POST',nil,@batch_obs)
        reply = @client.end_batch
        
        assert_bundle_response(reply)
        assert_equal(2, reply.resource.entry.length, "Expected 2 Bundle entries but found #{reply.resource.entry.length}", reply.body)

        patientCode = reply.resource.entry[0].try(:response).try(:status).try(:split).try(:first).try(:to_i)
        assert((!patientCode.nil? && patientCode >= 200 && patientCode < 300), "The batch should have created a Patient.", reply.body)
        # set the IDs to whatever the server created
        @batch_patient.id = FHIR::ResourceAddress.pull_out_id('Patient',reply.resource.entry[0].try(:response).try(:location))
        @batch_patient.id = (reply.resource.entry[0].resource.id rescue nil) if @batch_patient.id.nil?
 
        obsCode = reply.resource.entry[1].try(:response).try(:status).try(:split).try(:first).try(:to_i)
        # set the IDs to whatever the server created
        @batch_obs.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[1].try(:response).try(:location))
        @batch_obs.id = (reply.resource.entry[1].resource.id rescue nil) if @batch_obs.id.nil?
        assert((!obsCode.nil? && obsCode >= 400 && obsCode < 500), "The batch should have failed to create the Observation with a dependency on the Patient.", reply.body)
      end

      # Batch patient record
      test 'XFER11','Create Patient Record and then Batch create and search Observations' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/observation.html"
          requires resource: 'Patient', methods: ['create']
          requires resource: 'Observation', methods: ['create','search']
          requires resource: nil, methods: ['batch-system']
          validates resource: 'Patient', methods: ['create']
          validates resource: 'Observation', methods: ['create','search']
          validates resource: nil, methods: ['batch-system']
        }

        @batch_patient_2 = ResourceGenerator.minimal_patient("#{Time.now.to_i}",'Batch')
        reply = @client.create @batch_patient_2
        assert_response_ok(reply)
        @batch_patient_2.id = (reply.resource.try(:xmlId) || reply.id)

        # height
        @batch_obs_2 = ResourceGenerator.minimal_observation('http://loinc.org','8302-2',300,'cm',@batch_patient_2.id)
        # weight
        @batch_obs_3 = ResourceGenerator.minimal_observation('http://loinc.org','3141-9',500,'kg',@batch_patient_2.id)

        @client.begin_batch
        @client.add_batch_request('POST',nil,@batch_obs_2)
        @client.add_batch_request('POST',nil,@batch_obs_3)
        @client.add_transaction_request('GET',"Observation?patient=Patient/#{@batch_patient_2.id}")
        reply = @client.end_batch

        assert( ((200..299).include?(reply.code)), "Unexpected status code: #{reply.code}" )
        warning{ assert_response_ok(reply) }
        assert_bundle_response(reply)

         # set the IDs to whatever the server created
        @batch_obs_2.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[0].try(:response).try(:location))
        @batch_obs_2.id = (reply.resource.entry[0].resource.id rescue nil) if @batch_obs_2.id.nil?
        @batch_obs_3.id = FHIR::ResourceAddress.pull_out_id('Observation',reply.resource.entry[1].try(:response).try(:location))
        @batch_obs_3.id = (reply.resource.entry[1].resource.id rescue nil) if @batch_obs_3.id.nil?
 
        assert_equal(3, reply.resource.entry.length, "Expected 3 Bundle entries but found #{reply.resource.entry.length}", reply.body)
        assert_bundle_transactions_okay(reply)
        assert_equal(2, reply.resource.entry[-1].resource.entry.length, "Expected 2 search results but found #{reply.resource.entry[-1].resource.entry.length}", reply.body)
      end

      # Batch delete patient record
      test 'XFER12','Delete an Ordered Patient Record as Batch' do
        metadata {
          links "#{REST_SPEC_LINK}#transaction"
          links "#{BASE_SPEC_LINK}/patient.html"
          links "#{BASE_SPEC_LINK}/observation.html"
          requires resource: 'Patient', methods: ['delete']
          requires resource: 'Observation', methods: ['delete']
          requires resource: nil, methods: ['batch-system']
          validates resource: 'Patient', methods: ['delete']
          validates resource: 'Observation', methods: ['delete']
          validates resource: nil, methods: ['batch-system']
        }
        skip unless ((@batch_patient_2 && !@batch_patient_2.id.nil?) ||
                     (@batch_obs_2 && !@batch_obs_2.id.nil?) ||
                     (@batch_obs_3 && !@batch_obs_3.id.nil? ))

        @client.begin_batch
        @client.add_batch_request('DELETE', "Observation/#{@batch_obs_3.id}") if @batch_obs_3 && !@batch_obs_3.id.nil?
        @client.add_batch_request('DELETE', "Observation/#{@batch_obs_2.id}") if @batch_obs_2 && !@batch_obs_2.id.nil?
        @client.add_batch_request('DELETE', "Patient/#{@batch_patient_2.id}") if @batch_patient_2 && !@batch_patient_2.id.nil?
        reply = @client.end_batch

        assert( ((200..299).include?(reply.code)), "Unexpected status code: #{reply.code}" )
        warning{ assert_response_ok(reply) }
        assert_bundle_response(reply)
        assert_bundle_transactions_okay(reply)
      end
    end
  end
end
