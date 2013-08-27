require 'open-uri'

module FeedProcessorUtils

  class HTMLParser

    @@default_config = File.join(File.dirname(__FILE__), "config/html_parser.yml")

    def initialize(config_file = nil)
      config_file ||= @@default_config
      @config = YAML.load(File.read(config_file))
    end

    def parse_data(input)
      input_doc = Nokogiri::HTML(input)
      Hash[
        fields.map do |field_name, parsing_data|
          [field_name, extract_field(input_doc, parsing_data)]
        end
      ]
    end

    def parse_url(url)
      input = open(url).read
      parse_data(input)
    end

    private

    def extract_field(input_doc, parsing_data)
      if parsing_data[:collection]
        collection = []
        parsing_data[:selectors].each do |selector|
          elements = input_doc.css(selector)
          elements.each do |element|
            if element[parsing_data[:attribute]]
              collection << element[parsing_data[:attribute]]
            elsif parsing_data[:fallback_text]
              collection << element.text
            end
          end
        end
        collection
      else
        parsing_data[:selectors].each do |selector|
          element = input_doc.at_css(selector)
          if element
            return element[parsing_data[:attribute]] if element[parsing_data[:attribute]]
            return element.text if parsing_data[:fallback_text]
          end
        end
        nil
      end
    end

    def fields
      @config
    end

  end
end