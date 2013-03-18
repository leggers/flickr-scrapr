require 'mechanize'
require 'logger'
require 'sanitize'
require 'aws/s3'

# thingiverse scraper
# WHAT TO SCRAPE: one folder per item whose name is the product name

class Scraper

  # file and folder creation, doesn't actually do anything except change the directory right now
  def make_dirs
    FileUtils.mkdir 'thingiverse_stuff'#, :noop => true
    FileUtils.cd 'thingiverse_stuff'
  end

  def make_files
    separator = "|=|=|"
    new_line = "~!~!~\n"
    # id, name, link to product page, price, product description, product instructions (if any), link to CC license
    main_data = File.new "products.txt", File::CREAT|File::RDWR
    main_data.print "id#{separator}name#{separator}link#{separator}price#{separator}description#{separator}instructions#{separator}CC#{new_line}"
    
    #id, relationship, file_path (url)
    relationships_data = File.new "relationships.txt", File::CREAT|File::RDWR
    relationships_data.print "product_id#{separator}relationship#{separator}file_path#{new_line}"

    #id, category
    category_data = File.new "categories.txt", File::CREAT|File::RDWR
    category_data.print "product_id#{separator}category#{new_line}"

    #log to store how many featured product pages have been scraped
    log_file = File.new "log_file.txt", File::CREAT|File::RDWR

    return main_data, relationships_data, category_data, log_file
  end

  def scrape(main_data, relationships_data, category_data, log_file, start_page = "http://www.thingiverse.com/featured/page:0", start_id = 0, glob_id = 0)
    print "scraping"

    separator = "|=|=|"
    new_line = "~!~!~\n"

    #scraper creation
    $dude = Mechanize.new
    $dude.log = Logger.new "dude.log"
    $dude.user_agent_alias = 'Mac Safari'

    until start_page[-1].to_i > 10
      
      #getting next page
      page = $dude.get start_page.succ!
      log_file.write("started scraping #{start_page}\n")

      #all links to things from this featured page
      thing_links = page.links_with(:href => /\/thing:\d+/)

      #loop evaluating each on-page thign ONCE: hence the id*2 (thingaverse has two links per item on featured page: image and hyperlink)
      for id in start_id..thing_links.length/2-1
        thing = thing_links[id*2+1]
  	thing_page = thing.click
        if is_takeable?(thing_page)
          toWrite = "#{glob_id}#{separator}#{thing.to_s}#{separator}http://thingiverse.com#{thing.uri.to_s}#{separator}0#{separator}"

          dir_name = thing.to_s.gsub('/', '\\')
          dir_name = "#{glob_id}:" + dir_name
          FileUtils.mkdir dir_name unless File.exists? dir_name
          FileUtils.chdir dir_name


          download_files(thing_page, glob_id, separator, new_line, relationships_data)

          thing_description = get_description(thing_page)
          if thing_description
            toWrite += thing_description + "#{separator}"  
          else
            toWrite += '[none]' + "#{separator}"
          end

          thing_instructions = get_instructions(thing_page)
          if thing_instructions
            toWrite += thing_instructions + "#{separator}"
          else
            toWrite += '[none]' + "#{separator}"
          end

          license = get_copyright(thing_page)
          toWrite += license + "#{separator}"

          category = get_categories(thing_page)
          category_data.print "#{glob_id}#{separator}#{category}#{new_line}"

          main_data.print(toWrite+="#{new_line}")
          glob_id += 1
          FileUtils.cd '..'
          log_file.write("scraped item with start_id: #{start_id}\n")
        end
      end
      log_file.write("scraped #{start_page}\n")
    end
  end

  def is_takeable?(thing_page)
    url = thing_page.link_with(:href => /creativecommons/)
    notToReturn = /non-commercial/i.match(url.text) or /nc/i.match(url.href)
    not notToReturn
  end


  #should spit out something that looks like these below:
  #<div xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/" about="http://www.thingiverse.com/thing:27050"><span property="dct:title">Brown Bear (Ursus arctos) </span> (<a rel="cc:attributionURL" property="cc:attributionName" href="http://www.thingiverse.com/thing:27050">MakerBot</a>) / <a rel="license" href="http://creativecommons.org/licenses/by/3.0/">CC BY 3.0</a></div>
  #<div xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/" about="http://www.thingiverse.com/thing:45203"><span property="dct:title"> Chainmail</span> (<a rel="cc:attributionURL" property="cc:attributionName" href="http://www.thingiverse.com/thing:45203">walter</a>) / <a rel="license" href="http://creativecommons.org/licenses/by-nc/3.0/">CC BY-NC 3.0</a></div>
  #<div xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/" about="http://www.thingiverse.com/thing:47654"><span property="dct:title">Spin Top </span> (<a rel="cc:attributionURL" property="cc:attributionName" href="http://www.thingiverse.com/thing:47654">mariothemagician</a>) / <a rel="license" href="http://creativecommons.org/licenses/by-sa/3.0/">CC BY-SA 3.0</a></div>
  
  def get_copyright(thing_page)
    thing_url = thing_page.uri.to_s
    name_and_author = / by /i.match(thing_page.title)
    thing_name = name_and_author.pre_match.lstrip.rstrip
    thing_author = name_and_author.post_match.match(' - ').pre_match

    cc_link = thing_page.link_with(:href => /creativecommons/)
    license_info = /licenses\//.match(cc_link.href).post_match.match('/')
    attribution_type = license_info.pre_match.swapcase
    version = license_info.post_match[0..-2]

    attribution = "<div xmlns:cc=\"http://creativecommons.org/ns\#\" xmlns:dct=\"http://purl.org/dc/terms/\" about=\"#{thing_url}\"><span property=\"dct:title\">#{thing_name}</span> (<a rel=\"cc:attributionURL\" property=\"cc:attributionName\" href=\"#{thing_url}\">#{thing_author}</a>) / <a rel=\"license\" href=\"#{cc_link.uri}\">CC #{attribution_type} #{version}</a></div>"
    return attribution
  end

  def get_description(thing_page)
    description = /\<\/div\>/.match(/thing-detail-description/.match(thing_page.body).post_match).pre_match[5..-1].strip
    return description
  end

  def get_instructions(thing_page)
    instructions_match = /Instructions/.match(thing_page.body)
    if instructions_match
      instructions = /\<\/div\>/.match(instructions_match.post_match).pre_match.strip[5..-1].strip
    end
    return instructions
  end

  def download_files(thing_page, id, separator, new_line, relationships_data)
    #images
    image_div = thing_page.body.match(/thing-gallery-thumbs/)
    if image_div
      match1 = image_div.post_match.match(/data-image-url="/)
      while match1
        image_url = match1.post_match.match('"').pre_match
        if not image_url.match(/default/)
          image = $dude.get image_url
          image.save
          name = image_url.match(/(\/.*){2,}/)[1].to_s[1..-1]
          url = "NOT_UPLOADED_TO_S3"
          relationships_data.print "#{id}#{separator}image#{separator}#{url}#{new_line}"
        end
        match1 = match1.post_match.match(/data-image-url="/)
      end
    end

    #other files
    download_links = thing_page.links_with(:href => /download:\d+/)
    download_links.each do |link|
      file_name = link.attributes.to_s.match(/">/).post_match.match(/</).pre_match[0..-1]
      link.click.save("#{file_name}")
      url = "NOT_UPLOADED_TO_S3"
      relationships_data.print "#{id}#{separator}#{relationship(file_name)}#{separator}#{url}#{new_line}"
    end
  end

  def relationship(file_name)
    downcased = file_name.downcase
    if downcased.match '.stl'
      return 'stl'
    elsif downcased.match '.pdf'
      return 'pdf'
    elsif downcased.match '.zip'
      return 'zip'      
    end
    return 'other'  
  end

  def get_categories(thing_page)
    metadata = thing_page.body.match(/breadcrumbs/)
    if metadata
      metadata = metadata.post_match.match(/div>/).pre_match
      toReturn = metadata.match(/categories\//)#.post_match.match(/">/).pre_match
    end
    if toReturn
      begin
        toReturn = toReturn.post_match.match(/"/).pre_match
        cat2 = metadata.match(/categories\/#{toReturn}\//).post_match.match(/">/).pre_match
      rescue Exception => e
        return toReturn
      end
      toReturn += '>' + "#{cat2}" if cat2
    else
      toReturn = '[none]'
    end
    return toReturn
  end

  def establish_connection
    AWS::S3::Base.establish_connection!(:access_key_id => 'AKIAJAAN65BQBUEN2SHQ', :secret_access_key => '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')
    # bucket = AWS::S3:: Bucket.find('azavy')
  end

  #uploads file to S3, returns url
  def upload_file(id, file_name)
    puts file_name
    AWS::S3::S3Object.store("#{id}/"+file_name, open(file_name), 'azavy', :access => :public_read)
    return "http://s3.amazonaws.com/azavy/#{id}/#{file_name}"
  end

  # kicks it all off
  def scrape_everything
    puts "scrape_everything"
    make_dirs
    main_data, relationships_data, category_data, log_file = make_files
    establish_connection
    scrape(main_data, relationships_data, category_data, log_file)
  end

  #testing function
  def tester_func
    m = Mechanize.new
    # FileUtils.cd '/Users/leggerssignups/Azavy/thingiverse stuff/0:Blossoming Lamp'
    bear_page = m.get('http://www.thingiverse.com/thing:27050')
    spiked_car = m.get('http://www.thingiverse.com/thing:47689')
    chainmail = m.get('http://www.thingiverse.com/thing:45203')
    sa_license = m.get('http://www.thingiverse.com/thing:44959')
    get_copyright(sa_license)
    # is_takeable?(spiked_car)
    # relationships_data = File.new "relationships.txt", File::CREAT|File::RDWR
    # relationships_data.print "product_id|=|=|relationship|=|=|file_path~!~!~\n"
    # puts get_categories(bear_page)
    # establish_connection
    # download_files(bear_page, 0, "|=|=|", "~!~!~\n", relationships_data)
    # get_instructions(bear_page)
    # test_image = 'Makerbotting20120720-123_display_medium.jpg'
    # AWS::S3::S3Object.store(test_image, open(test_image), 'azavy', :access => :public_read)
    # AWS::S3::S3Object.store('test_bear', 'http://thingiverse-rerender.s3.amazonaws.com/renders/1e/5c/d7/cb/95/BrownBear_display_medium.jpg', 'azavy', :access => :public_read)
  end
end

s = Scraper.new
print s.scrape_everything
