module Crucible
  module Tests
    class ConnectathonSchedulingTrackTest < BaseSuite

      def id
        'ConnectathonSchedulingTrackTest'
      end

      def description
        'Connectathon Scheduling Track Test focuses on creating/cancelling Appointments and retreiving Schedules.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = 'Connectathon'
      end

      def setup
        @resources = Crucible::Generator::Resources.new

        # Create a patient
        @patient = @resources.minimal_patient
        @patient.xmlId = nil # clear the identifier, in case the server checks for duplicates
        reply = @client.create(@patient)      
        assert_response_ok(reply)
        @patient.xmlId = reply.id

        # Create a practitioner
        @practitioner = @resources.scheduling_practitioner
        @practitioner.xmlId = nil # clear the identifier, in case the server checks for duplicates
        reply = @client.create(@practitioner)      
        assert_response_ok(reply)
        @practitioner.xmlId = reply.id

        # Create a schedule
        @schedule = @resources.scheduling_schedule
        @schedule.xmlId = nil # clear the identifier, in case the server checks for duplicates
        @schedule.actor.reference = "Practitioner/#{@practitioner.xmlId}"
        reply = @client.create(@schedule)      
        assert_response_ok(reply)
        @schedule.xmlId = reply.id

        # Create a slot
        @slot = @resources.scheduling_slot
        @slot.xmlId = nil # clear the identifier, in case the server checks for duplicates
        @slot.schedule.reference = "Schedule/#{@schedule.xmlId}"
        reply = @client.create(@slot)      
        assert_response_ok(reply)
        @slot.xmlId = reply.id
      end

      def teardown
        @client.destroy(FHIR::Patient, @patient.xmlId) if !@patient.xmlId.nil?
        @client.destroy(FHIR::Practitioner, @practitioner.xmlId) if !@practitioner.xmlId.nil?
        @client.destroy(FHIR::Schedule, @schedule.xmlId) if !@schedule.xmlId.nil?
        @client.destroy(FHIR::Slot, @slot.xmlId) if !@slot.xmlId.nil?
        @client.destroy(FHIR::Appointment, @appointment.xmlId) if @appointment && !@appointment.xmlId.nil?
        @client.destroy(FHIR::AppointmentResponse, @appointment_response_patient.xmlId) if @appointment_response_patient && !@appointment_response_patient.xmlId.nil?
        @client.destroy(FHIR::AppointmentResponse, @appointment_response_practitioner.xmlId) if @appointment_response_practitioner && !@appointment_response_practitioner.xmlId.nil?
      end

      # Find Practitioner's schedule
      test 'CST01','Find Practitioner\'s Schedule' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/schedule.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Schedule', methods: ['search']
          validates resource: 'Schedule', methods: ['search']
        }

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'actor' => "Practitioner/#{@practitioner.xmlId}"
            }
          }
        }
        reply = @client.search(FHIR::Schedule, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(1, reply.resource.entry.size, 'There should only be one Schedule for the test Practitioner currently in the system.', reply.body)
        assert_equal(@schedule.xmlId, reply.resource.entry[0].try(:resource).try(:xmlId), 'The correct Schedule was not returned.', reply.body)
      end

      # Find Slot in Practitioner's schedule
      test 'CST02','Find Slot in Practitioner\'s Schedule' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/slot.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Slot', methods: ['search']
          validates resource: 'Slot', methods: ['search']
        }

        options = {
          :search => {
            :flag => false,
            :compartment => nil,
            :parameters => {
              'schedule' => "Schedule/#{@schedule.xmlId}"
            }
          }
        }
        reply = @client.search(FHIR::Slot, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal(1, reply.resource.entry.size, 'There should only be one Slot for the test Practitioner\'s Schedule currently in the system.', reply.body)
        assert_equal(@slot.xmlId, reply.resource.entry[0].try(:resource).try(:xmlId), 'The correct Slot was not returned.', reply.body)
      end

      # Create appointment in slot (proposed) 
      test 'CST03','Create Proposed Appointment in Slot' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/appointment.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Appointment', methods: ['create']
          validates resource: 'Appointment', methods: ['create']
        }
        @appointment = @resources.scheduling_appointment
        @appointment.xmlId = nil # clear the identifier
        @appointment.participant[0].actor.reference = "Patient/#{@patient.xmlId}"
        @appointment.participant[1].actor.reference = "Practitioner/#{@practitioner.xmlId}"
        reply = @client.create(@appointment)      
        assert_response_ok(reply)
        @appointment.xmlId = reply.id
      end 

      # Update slot status (busy-tentative)
      test 'CST04','Update Slot status to busy-tentative' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/slot.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Slot', methods: ['update']
          validates resource: 'Slot', methods: ['update']
        }
        @slot.freeBusyType = 'busy-tentative'
        reply = @client.update(@slot,@slot.xmlId)      
        assert_response_ok(reply)
      end   

      # Create appointment response for patient (accepted)
      test 'CST05','Create AppointmentResponse for Patient (accepted)' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/appointmentresponse.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'AppointmentResponse', methods: ['create']
          validates resource: 'AppointmentResponse', methods: ['create']
        }
        @appointment_response_patient = @resources.scheduling_response_patient
        @appointment_response_patient.xmlId = nil # clear the identifier
        @appointment_response_patient.appointment.reference = "Appointment/#{@appointment.xmlId}"
        reply = @client.create(@appointment_response_patient)      
        assert_response_ok(reply)
        @appointment_response_patient.xmlId = reply.id
      end 

      # Update appointment.participant.status for patient (accepted)
      test 'CST06','Update Appointment.participant.status for Patient (accepted)' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/appointment.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Appointment', methods: ['update']
          validates resource: 'Appointment', methods: ['update']
        }
        @appointment.participant[0].status = 'accepted'
        reply = @client.update(@appointment,@appointment.xmlId)      
        assert_response_ok(reply)
      end

      # Create appointment response for practitioner
      test 'CST07','Create AppointmentResponse for Practitioner (accepted)' do
        metadata {
          links "#{REST_SPEC_LINK}#create"
          links "#{BASE_SPEC_LINK}/appointmentresponse.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'AppointmentResponse', methods: ['create']
          validates resource: 'AppointmentResponse', methods: ['create']
        }
        @appointment_response_practitioner = @resources.scheduling_response_practitioner
        @appointment_response_practitioner.xmlId = nil # clear the identifier
        @appointment_response_practitioner.appointment.reference = "Appointment/#{@appointment.xmlId}"
        reply = @client.create(@appointment_response_practitioner)      
        assert_response_ok(reply)
        @appointment_response_practitioner.xmlId = reply.id
      end 

      # Update appointment.participant.status for Practitioner (accepted)
      test 'CST08','Update Appointment.participant.status for Practitioner (accepted)' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/appointment.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Appointment', methods: ['update']
          validates resource: 'Appointment', methods: ['update']
        }
        @appointment.participant[1].status = 'accepted'
        reply = @client.update(@appointment,@appointment.xmlId)      
        assert_response_ok(reply)
      end
 
      # Update slot status (busy)
      test 'CST09','Update Slot status (busy)' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/slot.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Slot', methods: ['update']
          validates resource: 'Slot', methods: ['update']
        }
        @slot.freeBusyType = 'busy'
        reply = @client.update(@slot,@slot.xmlId)      
        assert_response_ok(reply)
      end  

      # Update appointment status (booked)
      test 'CST10','Update Appointment status (booked)' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/appointment.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Appointment', methods: ['update']
          validates resource: 'Appointment', methods: ['update']
        }
        @appointment.status = 'booked'
        reply = @client.update(@appointment,@appointment.xmlId)      
        assert_response_ok(reply)
      end 

      # Update appointment status (cancelled)
      test 'CST11','Update Appointment status (cancelled)' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/appointment.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Appointment', methods: ['update']
          validates resource: 'Appointment', methods: ['update']
        }
        @appointment.status = 'cancelled'
        reply = @client.update(@appointment,@appointment.xmlId)      
        assert_response_ok(reply)
      end 

      # Update slot status (free)
      test 'CST12','Update Slot status (free)' do
        metadata {
          links "#{REST_SPEC_LINK}#update"
          links "#{BASE_SPEC_LINK}/slot.html"
          links 'http://wiki.hl7.org/index.php?title=FHIR_Connectathon_10#Track_6_-_Scheduling'
          requires resource: 'Slot', methods: ['update']
          validates resource: 'Slot', methods: ['update']
        }
        @slot.freeBusyType = 'free'
        reply = @client.update(@slot,@slot.xmlId)      
        assert_response_ok(reply)
      end 

    end
  end
end
