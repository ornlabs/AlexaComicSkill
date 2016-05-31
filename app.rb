require 'digest'
require 'json'
require 'rest-client'
require 'sinatra'

require './apis/marvel'

configure do
  set :root, File.dirname(__FILE__)
end

post '/' do
  begin
    request.body.rewind
    request_payload = JSON.parse request.body.read

    puts "REQUEST:\n"
    puts request_payload

    if request_payload['request']['type'] == 'LaunchRequest'
      launch_response = {
        "version" => "1.0",
        "response" => {
          "outputSpeech" => {
            "type" => "PlainText",
            "text" => "What would you like to know?"
          },
          "shouldEndSession" => false
        }
      }
      return JSON.generate(launch_response)
    else
      # Get intent, send to appropriate method.
      intent = request_payload['request']['intent']['name']

      if intent == "GetBasicInfo"
        res = get_basic_info(request_payload)
      else
        res = JSON.generate(build_res_obj("Error",
              "I'm sorry, I'm not sure what you meant."))
      end

      return res
    end
  rescue => e
    puts "ERROR\n" + e.message

    error_response = {
      "version" => "1.0",
      "response" => {
        "outputSpeech" => {
          "type" => "PlainText",
          "text" => "I'm sorry, there was an error."
        },
        "shouldEndSession" => true
      }
    }
    return JSON.generate(error_response)
  end
end

def get_basic_info(req)

  subject = req['request']['intent']['slots']['Character']['value']
  description = ""
  attribution = ""
  pic_url = ""
  card_text = ""

  # Query different sources for matches.
  ## Marvel
  marvel_found = false

  params = {
    'name' => subject
  }

  begin
    marvel = Marvel.new
    marvel_res = marvel.query("characters", params)

    if marvel_res["code"] == 200 && marvel_res["data"]["total"] > 0
      marvel_found = true
    end
  rescue NameError => e
    puts "Error while examining Marvel API response.\n" + e.message
  rescue RestClient::ResourceNotFound => e
    puts "Error calling Marvel API.\n" + e.response
  end

  ## Comic Vine
  cv_found = false

  begin
    cv = ComicVine.new
    cv_res = cv.search("character", subject)

    unless cv_res["number_of_page_results"] == 0
      cv_found = true
      cv_res = cv.get_single_result(cv_res)
    end
  rescue NameError => e
    puts "Error while examining Comic Vine API response.\n" + e.message
  rescue RestClient::ResourceNotFound => e
    puts "Error calling Comic Vine API.\n" + e.response
  end

  # Review results from APIs, and decide what to return.
  res = {}
  ## No Results
  if !marvel_found && !cv_found
    subject = subject.split.map(&:capitalize).join(' ')
    res = build_res_obj("Could Not Find #{subject}",
          "I'm sorry, I could not find any information about #{subject}.")
    return JSON.generate(res)
  end
  ## Description
  if marvel_found && marvel_res["data"]["results"][0]["description"] != ""
    description = marvel_res["data"]["results"][0]["description"]
  elsif cv_found && cv_res[deck] != nil
    description = cv_res[deck]
  else
    description = "No description is available for #{subject}."
  end
  ## Attribution
  if marvel_found && cv_found
    attribution = "Sources:\n" +
    marvel_res["attributionText"] +
    "\nComic Vine | http://comicvine.gamespot.com"
  elsif marvel_found
    attribution = "Sources:\n" + marvel_res["attributionText"]
  else
    attribution = "Sources:\nComic Vine | http://comicvine.gamespot.com"
  end
  ## Picture
  if marvel_found && marvel_res["data"]["results"][0]["thumbnail"] != nil
    pic_url = marvel_res["data"]["results"][0]["thumbnail"]["path"] +
              "/standard_fantastic." +
              marvel_res["data"]["results"][0]["thumbnail"]["extension"]
  end
  # Turn http to https
  unless thumbnail.start_with?("https")
    thumbnail = "https" + thumbnail[4..-1]
  end

  res = build_res_obj(subject, description, attribution, pic_url)
  return JSON.generate(res)
end

# attribution, card_text, and card_image are optional.
# If nothing is passed, card_text will be the same as speech_text.
# For no card text, pass an empty string.
def build_res_obj(card_title, speech_text, attribution = "", card_image = nil, card_text = nil)
  res = {
    "version" => "1.0",
    "response" => {
      "outputSpeech" => {
        "type" => "PlainText",
        "text" => speech_text
      },
      "card" => {
        "title" => card_title
      },
      "shouldEndSession" => true
    }
  }

  if card_text == nil
    card_text = speech_text
  end

  if attribution != ""
    card_text += "\n\n" + attribution
  end

  if card_image == nil
    res["response"]["card"]["type"] = "Simple"
    res["response"]["card"]["content"] = card_text
  else
    res["response"]["card"]["type"] = "Standard"
    res["response"]["card"]["text"] = card_text
    res["response"]["card"]["image"] = {
      "largeImageUrl" => card_image
    }

  end

  return res
end
