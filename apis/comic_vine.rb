module ComicVine

  # path: The path of the resource type (plural form).
  # filter: Format "field:value,field:value"
  # field_list: Field to include, deliminated with comma, default is all
  def ComicVine.query(path, filter, field_list = nil)

    request_url = "http://comicvine.gamespot.com/api/" + path + "/"

    params = {
      "api_key" => ENV['COMIC_VINE_KEY'],
      "format" => "json",
      "filter" => filter
    }

    if field_list
      params["field_list"] = field_list
    end

    params = {
      :params => params
    }

    return JSON.parse((RestClient.get request_url, params).body)
  end

  # Doesn't work with every resource type - only when you want to search
  # by name and select based upon number of comic books appearances.
  # In other cases, use ComicVine.query and write custom logic.
  def ComicVine.get_by_name(name, path, field_list = nil)
    found = false
    filter = "name:" + name

    begin
      res = query(path, filter, field_list)

      if res["number_of_page_results"] > 0
        found = true

        highest_count = 0
        result_index = 0

        res["results"].each_with_index do |result, index|
          if result["count_of_issue_appearances"] > highest_count
            highest_count = result["count_of_issue_appearances"]
            result_index = index
          end
        end
      end
    rescue NameError => e
      puts "Error while examining Comic Vine API response.\n" + e.message
    rescue RestClient::ResourceNotFound => e
      puts "Error calling Comic Vine API.\n" + e.response
    end

    return res["results"][result_index], found
  end
end
