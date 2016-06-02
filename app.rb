require 'digest'
require 'json'
require 'rest-client'
require 'sinatra'

require_relative 'apis/comic_vine'
require_relative 'apis/marvel'
require_relative 'utils/utils'

post '/' do
  begin
    request.body.rewind
    request_payload = JSON.parse request.body.read

    puts "REQUEST:\n"
    puts request_payload

    req_app_id = request_payload["session"]["application"]["applicationId"]

    # Send error message if request is not from our skill.
    if req_app_id != ENV['ALEXA_APP_ID']
      puts "ERROR: Incorrect App ID: " + req_app_id
      bad_app_id_message = "This skill is incorrectly configured. " +
                           "Please contact the skill creator. Good-bye!"
      return Utils.build_end_res_obj(bad_app_id_message)
    # Launch request (no intent).
    elsif request_payload['request']['type'] == 'LaunchRequest'
      message = "Welcome to Comic Book Guide. What would you like to know?"
      return Utils.build_res_obj(message)
    # Intent Request
    elsif request_payload['request']['type'] == 'IntentRequest'
      # Get intent, send to appropriate method.
      intent = request_payload['request']['intent']['name']

      if intent == "GetBasicInfo"
        res = get_basic_info(request_payload)
      elsif intent == "GetBirthDate"
        res = get_birth_date(request_payload)
      elsif intent == "AMAZON.StopIntent" || intent == "AMAZON.CancelIntent"
        res = end_session(request_payload)
      else
        message = "This skill is incorrectly configured. Please contact the " +
                  "skill creator. Good-bye!"
        res = Utils.build_end_res_obj(message)
      end

      return res
    # SessionEndedRequest, no action needed
    else
      puts "Session Ended."
      return ""
    end
  rescue => e
    puts "ERROR\n" + e.message
    puts e.backtrace

    message = "I'm sorry, there was an error in this skill. Good-bye!"
    return Utils.build_end_res_obj(message)
  end
end

def get_basic_info(req)
  subject = Utils.unposs(req['request']['intent']['slots']['Character']['value'])
  description = ""
  attribution = ""
  pic_url = nil
  card_text = ""

  cv_fields = "aliases,birth," +
  "count_of_issue_appearances,creators,deck,first_appeared_in_issue," +
  "gender,image,movies,name,powers,publisher,real_name,teams"

  marvel_res, marvel_found = Marvel.get_character(subject)
  cv_res, cv_found = ComicVine.get_by_name(subject, "characters", cv_fields)
  puts cv_res
  # Review results from APIs, and decide what to return.
  res = {}
  ## No Results
  if !marvel_found && !cv_found
    subject = subject.split.map(&:capitalize).join(' ')
    message = "I'm sorry, I could not find any information about #{subject}."
    return Utils.build_res_obj(message)
  end
  ## Description
  if marvel_found && marvel_res["data"]["results"][0]["description"] != ""
    description = marvel_res["data"]["results"][0]["description"]
  elsif cv_found && cv_res["deck"] != nil
    description = cv_res["deck"]
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
  if pic_url != nil && !(pic_url.start_with?("https"))
    pic_url = "https" + pic_url[4..-1]
  end

  return Utils.build_res_obj(description, subject, subject, attribution, pic_url)
end

def get_birth_date(req)
  subject = Utils.determine_subject(req, "Character")

  cv_res, cv_found = ComicVine.get_by_name(subject, "characters", "birth,name")

  if !cv_found || cv_res["birth"] == nil
    message = "I could not find a birth date for #{subject}."
    return Utils.build_res_obj(message)
  else
    message = "#{cv_res["name"]} was born on #{cv_res["birth"]}."
    return Utils.build_res_obj(message)
  end
end

def end_session(req)
  return Utils.build_end_res_obj("Good-bye!")
end
