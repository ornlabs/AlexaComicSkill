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

  def ComicVine.get_detailed_info(full_path)
    field_list = "aliases,birth," +
    "count_of_issue_appearances,creators,deck,first_appeared_in_issue," +
    "gender,image,name,powers,publisher,real_name,teams"

    params = {
      "api_key" => ENV['COMIC_VINE_KEY'],
      "format" => "json",
      "field_list" => field_list
    }

    params = {
      :params => params
    }

    return JSON.parse((RestClient.get full_path, params).body)
  end

  # Doesn't work with every resource type - only when you want to search
  # by name and select based upon number of comic books appearances.
  # In other cases, use ComicVine.query and write custom logic.
  # name and count_of_issue_appearances are added to the passed field_list
  def ComicVine.get_by_name(name, path)
    found = false
    filter = "name:" + name

    search_field_list = "api_detail_url,count_of_issue_appearances,name"

    begin
      res = query(path, filter, search_field_list)
      result = nil

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

        # Get more detailed info about the selected result.
        detail_path = res["results"][result_index]["api_detail_url"]

        result = get_detailed_info(detail_path)["results"]
      end
    rescue NameError => e
      puts "Error while examining Comic Vine API response.\n" + e.message
    rescue RestClient::ResourceNotFound => e
      puts "Error calling Comic Vine API.\n" + e.response
    end

    return result, found
  end
end
