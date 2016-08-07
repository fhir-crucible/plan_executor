module Crucible
  module Tests
    class ArgonautProviderConnectathonTest < BaseSuite
      def id
        'ArgonautProviderConnectathonTest'
      end

      def description
        'Test suite for the Argonaut Provider Directory Virtual Connectathon'
      end

      def initialize(client1, client2 = nil)
        super(client1, client2)
      end

      def setup

      end

      test 'APCT01', 'Test Ability to locate a Practitioner\'s Telecom/Physical Address' do
        
      end
    end
  end
end
