require 'mechanize'
require 'logger'
require 'sanitize'
require 'aws/s3'

class Scraper

  def start url
    $guy = Mechanize.new
    $guy.log = Logger.new 'guy.log'
    name = /photos\//.match(url).post_match.match('/').pre_match
    images_file = make_dir name
    make_files
    scrape(images_file, url, name)
  end

  def make_dir name
    p name
    begin
      FileUtils.mkdir name
    rescue Exception => e
      
    end
    FileUtils.cd name
  end

  def make_files
    separator = "|=|=|"
    new_line = "~!~!~\n"
    File.new "images.txt", "a+"
  end

  def scrape(data_file, url, name)
   page = $guy.get url
   # p page
   rest_of_page = page.body.match(/photo-display-container/)
   while rest_of_page
    rest_of_page = rest_of_page.post_match.match(/href="/).post_match
    pic_url = "http://www.flickr.com/#{rest_of_page.match('"').pre_match}/lightbox/"
    pic_page = $guy.get pic_url
    sizes_page = pic_page.link_with(href: /sizes/).click
    size_links = sizes_page.links_with(href: /sizes/)
    pic_number = get_number(pic_url, name)
    original = original_image(size_links, pic_number)
    exit
   end
  end

  def get_number(pic_url, name)
    return pic_url.match("#{name}/").post_match.match("/in").pre_match
  end

  def original_image(size_links, pic_number)
    for link in size_links
      if link.text.match(/original/i)
        image_page = link.click
        # p pic_number
        # p image_page
        image = image_page.image_with(src: /staticflickr/)
        p image
      end
    end
  end
end

s = Scraper.new
s.start 'http://www.flickr.com/photos/totaviva/sets/72157632174398126/'