require 'mechanize'
require 'logger'

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
    FileUtils.cd 'files'
    begin
      FileUtils.mkdir name
    rescue Exception => e
      p e #will rescue errno::exists and prompt user to delete folder or add to it... i hope
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
   image_links = page.links_with(href: /\/in\/set/)
   for pic_link in image_links.uniq{|x| x.to_s} do
    pic_page = pic_link.click
    sizes_page = pic_page.link_with(href: /sizes/).click
    size_links = sizes_page.links_with(href: /sizes/)
    original = original_image size_links
   end
  end
 
  def original_image size_links
    for link in size_links
      if link.text.match(/original/i)
        # p link
        image_page = link.click
        image_url = image_page.image_with(src: /staticflickr/).url
        image = $guy.get image_url
        image.save
      end
    end
  end
end

s = Scraper.new
s.start 'http://www.flickr.com/photos/totaviva/sets/72157632174398126/'