class Marvel
  def initialize()
  end

  def query(path, params)

    request_url = "http://gateway.marvel.com:80/v1/public/" + path

    timestamp = Time.now.to_i.to_s # .to_i returns unix timestamp, .to_s makes it a string

    params["ts"] = timestamp
    params["apikey"] = ENV['MARVEL_PUB_KEY']
    params["hash"] = Digest::MD5.hexdigest(timestamp + ENV['MARVEL_PRI_KEY'] + ENV['MARVEL_PUB_KEY'])

    params = {
      :params => params
    }

    return JSON.parse((RestClient.get request_url, params).body)
  end
end
