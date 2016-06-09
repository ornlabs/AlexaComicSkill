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

    res = RestClient.get request_url, params
    return JSON.parse(res.body)
  end

  # Searches over multiple resource types.
  def ComicVine.search(subject)
    request_url = "http://comicvine.gamespot.com/api/search/"

    params = {
      "api_key" => ENV['COMIC_VINE_KEY'],
      "format" => "json",
      "resources" => "character,concept,object,location,publisher,person,team",
      "query" => subject
    }

    params = {
      :params => params
    }

    begin
      response = RestClient.get request_url, params
      results = JSON.parse(response.body)

      exact_matches = []

      results["results"].each do |result|
        if result["name"].downcase == subject.downcase
          exact_matches << result
        end
      end

      if exact_matches == []
        results["results"].each do |result|
          if result["name"].downcase == "the " + subject.downcase
            exact_matches << result
          end
        end

        if exact_matches == []
          return nil, false
        end
      end

      best_result = exact_matches.max_by do |match|
        if match["count_of_issue_appearances"] != nil
          match["count_of_issue_appearances"]
        else
          0
        end
      end

      detail_path = best_result["api_detail_url"]
      det_result = get_detailed_info(detail_path)["results"]
      return det_result, true, best_result["resource_type"]
    rescue NameError => e
      puts "Error while examining Comic Vine API response.\n" + e.message
    rescue RestClient::Exception => e
      puts "Error calling Comic Vine API.\n"
      puts e.response
    end

    return nil, false
  end

  def ComicVine.get_detailed_info(full_path)
    field_list = "aliases,birth," +
    "count_of_issue_appearances,creators,deck,first_appeared_in_issue," +
    "gender,image,name,powers,publisher,real_name,teams,site_detail_url"

    if full_path.include? "issue"
      field_list = "cover_date,deck,image,issue_number,name,site_detail_url," +
      "volume"
    elsif full_path.include? "team"
      field_list = "aliases,characters,first_appeared_in_issue,publisher," +
      "name,count_of_issue_appearances,deck"
    elsif (full_path.include? "location") || (full_path.include? "object")
      field_list = "aliases,first_appeared_in_issue," +
      "name,count_of_issue_appearances,deck"
    end

    params = {
      "api_key" => ENV['COMIC_VINE_KEY'],
      "format" => "json",
      "field_list" => field_list
    }

    params = {
      :params => params
    }

    res = RestClient.get full_path, params
    return JSON.parse(res.body)
  end

  # Doesn't work with every resource type - only when you want to search
  # by name and select based upon number of comic books appearances.
  # In other cases, use ComicVine.query and write custom logic.
  def ComicVine.get_by_name(name, path)
    found = false
    filter = "name:" + name

    search_field_list = "api_detail_url,count_of_issue_appearances,name"

    begin
      res = query(path, filter, search_field_list)
      det_info = nil

      if res["number_of_page_results"] > 0
        found = true

        highest_count = 0
        result_index = 0

        res["results"].each_with_index do |result, index|
          if result["count_of_issue_appearances"] != nil
            if result["count_of_issue_appearances"] > highest_count
              highest_count = result["count_of_issue_appearances"]
              result_index = index
            end
          end
        end

        # Get more detailed info about the selected result.
        detail_path = res["results"][result_index]["api_detail_url"]

        det_info = get_detailed_info(detail_path)["results"]
      end
    rescue NameError => e
      puts "Error while examining Comic Vine API response.\n" + e.message
    rescue RestClient::Exception => e
      puts "Error calling Comic Vine API.\n" + e.response
    end

    return det_info, found
  end
end
