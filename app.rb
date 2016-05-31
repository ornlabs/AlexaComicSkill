require 'digest'
require 'json'
require 'rest-client'
require 'sinatra'

require './apis/marvel'

configure do
  set :root, File.dirname(__FILE__)
end

post '/' do
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
      res = {}
      #TODO - Send error message.
    end

    return res
  end
end

def get_basic_info(req)

  subject = req['request']['intent']['slots']['Character']['value']

  # Query different sources for matches.

  ## Marvel
  params = {
    'name' => subject
  }
  @marvel = Marvel.new
  marvel_res = @marvel.query("characters", params)

  ## SWAPI
  # TODO

  # Review results from APIs, and decide what to return.

  res = {}

  # If Marvel found the character, return the description, if there is one.
  begin
    if marvel_res["data"]["results"][0]["description"] != ""
      subject = subject.split.map(&:capitalize).join(' ')
      source_text = marvel_res["data"]["results"][0]["description"]
      attribution = marvel_res["attributionText"]
      thumbnail = marvel_res["data"]["results"][0]["thumbnail"]
      if thumbnail != nil
        thumbnail = thumbnail["path"] + "/standard_fantastic." + thumbnail["extension"]
        unless thumbnail.start_with?("https")
          thumbnail = "https" + thumbnail[4..-1]
        end
      end
      res = build_res_obj(subject, source_text, attribution, thumbnail)
    else
      res = build_res_obj("No Information Found", "I could not find any information about #{subject}.")
    end
  rescue NameError => e
    puts "NameError: " + e.message
    res = build_res_obj("No Information Found", "I could not find any information about #{subject}.")
  end

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
