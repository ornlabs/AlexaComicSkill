module Marvel
  def Marvel.query(path, params)

    request_url = "http://gateway.marvel.com:80/v1/public/" + path

    # .to_i returns unix timestamp, .to_s makes it a string
    timestamp = Time.now.to_i.to_s

    params["ts"] = timestamp
    params["apikey"] = ENV['MARVEL_PUB_KEY']
    params["hash"] = Digest::MD5.hexdigest(timestamp +
                     ENV['MARVEL_PRI_KEY'] + ENV['MARVEL_PUB_KEY'])

    params = {
      :params => params
    }

    return JSON.parse((RestClient.get request_url, params).body)
  end

  def Marvel.get_character(subject)
    found = false

    begin
      res = query("characters", { "name" => subject })

      if res["code"] == 200 && res["data"]["total"] > 0
        found = true
      end
    rescue NameError => e
      puts "Error while examining Marvel API response.\n" + e.message
    rescue RestClient::ResourceNotFound => e
      puts "Error calling Marvel API.\n" + e.response
    end

    return res, found
  end
end
