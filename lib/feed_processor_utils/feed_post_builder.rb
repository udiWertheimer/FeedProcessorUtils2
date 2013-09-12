require 'newer_image_size'
require 'image_size'

module FeedProcessorUtils
  class FeedPostBuilder

    @@config_file = File.join(File.dirname(__FILE__), 'config/feed_post_builder.yml')

    def self.sanitize(text)
      return nil unless text 
      replacements.each do |pattern, replacement|
        text.gsub!(pattern, replacement)
      end
      text
    end

    def self.ensure_absolute(url, host)
      url[0] == "/" ? "http://"+ host + url : url 
    end

    def self.match_based64?(uri)
      /data:\w+\/\w+;base64,/.match(uri)
    end

    def self.longest_content(*strings)
      strings.sort_by! do |string|
        string.to_s.gsub(/[\n\r]/,' ').gsub(/&nbsp;/, " ").gsub(/(<\/?[^<>]+>)/,' ').gsub(/\s{2,}/, ' ').gsub(/ / ,' ').split(' ').size
      end
      strings.last
    end

    def self.get_image_dimensions(uri)
      match = match_based64?(uri)
      if match
        data = Base64.decode64(uri.split(match[0])[1])
      else
        begin
          file = open(uri)
        rescue => e
          return [0,0]
        end
        data = file.read
      end

      if file && data.encoding.name == "UTF-8"
        NewerImageSize.new(file).size
      else
        ImageSize.new(data).get_size
      end

    end

    def self.dimensions_ok?(dimensions)
      ratio = (0.5..2.5).cover?(dimensions.first.to_f / dimensions.last.to_f) unless dimensions.last.to_i == 0
      ratio ||= false

      ratio && have_minimum_size?(dimensions)
    end

    def self.have_minimum_size?(dimensions)
      dimensions.first.to_i >= 300 && dimensions.last.to_i >= 150
    end
    
    def self.get_images(item_data, is_news, customized = "default")
      customized ||= "default"
      image_urls = []
      domain = URI.parse(item_data[:url] || item_data[:id])
      specific_images = if customized == "default"
        [:og_image, :image]
      elsif customized == "og_image"
        [:og_image]
      elsif customized == "html_images"
        [:image]
      else
        []
      end
      specific_images.each do |key|
        url = item_data[key]
        if url
          url = ensure_absolute(url.to_s, domain.to_s)
          if have_minimum_size?(get_image_dimensions(url))
            break if image_urls << url
          end
        end
      end
      if ["default", "lazy_images", "html_images"].include?(customized)
        nominated_images = if ["default", "lazy_images"].include?(customized) && item_data[:lazy_image_tags].present?
          item_data[:lazy_image_tags]
        else
          item_data[:images_in_text]
        end
        with_size = nominated_images.map do |url|
          {url: url, dim: get_image_dimensions(url)}
        end
        largest_img = with_size.sort_by do |img|
          dim = img[:dim]
          dim ? dim[0] * dim[1] : 0
        end.last
        if largest_img
          if is_news
            image_urls << largest_img[:url] if largest_img[:dim] && have_minimum_size?(largest_img[:dim])
          else
            image_urls.unshift(largest_img[:url]) if largest_img[:dim] && dimensions_ok?(largest_img[:dim])
          end
        end
      end
      image_urls
    end

    def self.get_videos(item_data)
      item_data[:videos_in_text].map do |video|
        video = "http:" + video if video[0..1] == "//" # sometimes the protocol is omitted from video url
        video
      end
    end


    def self.config
      @@config ||= YAML.load(File.read(@@config_file))
    end

    def self.replacements
      config[:replacements]
    end

  end
end