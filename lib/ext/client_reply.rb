module FHIR
  class ClientReply

    def response_format
      doc = Nokogiri::XML(self.body)
      if doc.errors.empty?
        FHIR::Formats::ResourceFormat::RESOURCE_XML
      else
        begin
          JSON.parse(self.body)
          FHIR::Formats::ResourceFormat::RESOURCE_JSON
        rescue JSON::ParserError => e
          raise "Failed to detect response format: #{self.body}"
        end
      end
    end

  end
end
