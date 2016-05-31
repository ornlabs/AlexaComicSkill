class ComicVine
  def initialize()
  end

  def search(resource_type, query)

    request_url = "http://comicvine.gamespot.com/api/search/"

    params = {
      "api_key" => ENV['COMIC_VINE_KEY'],
      "format" => "json",
      "resources" => resource_type,
      "query" => query
    }

    puts params

    return JSON.parse((RestClient.get request_url, params).body)

  end

  def get_single_result(search_results)
    result_index = search_results["results"].index{ |result|
      result["name"].downcase == query.downcase
    }

    return search_results["results"][result_index]
  end
end
