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
    scrape(images_file, url)
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

  def scrape(data_file, url)
   page = $guy.get url
   # p page
   rest_of_page = page.body.match(/photo-display-container/)
   while rest_of_page
    rest_of_page = rest_of_page.post_match.match(/href="/).post_match
    pic_url = "http://www.flickr.com/#{rest_of_page.match('"').pre_match}/lightbox/"
    pic_page = $guy.get pic_url
    sizes_page = pic_page.link_with(href: /sizes/).click
    p sizes_page
    exit
   end
  end
end

s = Scraper.new
s.start 'http://www.flickr.com/photos/totaviva/sets/72157632174398126/'