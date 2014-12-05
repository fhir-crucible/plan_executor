module Crucible
  module Tests
    class SprinklerSearchTest < BaseTest

      def id
        'Search001'
      end

      def description
        'Initial Sprinkler tests () for testing search capabilities.'
      end

      def setup
        @resources = Crucible::Generator::Resources.new
        @patient = @resources.example_patient

        @create_date = Time.now.utc

        @version = []
        result = @client.create(@patient)
        @id = result.id
        @version << result.version

        @patient.telecom << FHIR::Contact.new(system: 'email', value: 'foo@example.com')

        update_result = @client.update(@patient, @id)
        @version << update_result.version

        reply = @client.read_feed(FHIR::Patient)
        @total_count = 0
        @entries = []

        while reply != nil
          @total_count += reply.resource.entries.count
          @entries += reply.resource.entries
          reply = @client.next_page(reply)
        end
      end

      def teardown
        @client.destroy(FHIR::Patient, @id)
      end

      test 'SE01','Search patients without criteria (except _count)' do
        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              '_count' => '1'
            }
          }
        }
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.all_entries.size, 'The server did not return the correct number of results.'
        warning { assert_equal 1, reply.resource.size, 'The server did not report the correct number of results.' }
      end

      test 'SE02', 'Search on non-existing resource' do
        options = {
          :resource => Crucible::Tests::SprinklerSearchTest,
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => nil
          }
        }
        reply = @client.search_all(options)
        assert_response_not_found(reply)
      end

      test 'SE03','Search patient resource on partial family surname' do
        search_string = @patient.name[0].family[0][0..2]
        search_regex = Regexp.new(search_string)
        # how many patients in the bundle have matching names?
        expected = 0
        @entries.each do |entry|
          patient = entry.resource
          isMatch = false
          patient.name.each do |name|
            name.family.each do |family|
              if !(family =~ search_regex).nil?
                isMatch = true
              end
            end
          end
          expected += 1 if isMatch
        end

        options = {
          :search => {
            :flag => true,
            :compartment => nil,
            :parameters => {
              'family' => search_string
            }
          }
        }
        reply = @client.search(FHIR::Patient, options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal expected, reply.resource.size, 'The server did not report the correct number of results.'
      end      



    end
  end
end
