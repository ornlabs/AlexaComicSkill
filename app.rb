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
      elsif intent == "GetAliases"
        res = get_aliases(request_payload)
      elsif intent == "GetBirthDate"
        res = get_birth_date(request_payload)
      elsif intent == "GetFirstIssue"
        res = get_first_issue(request_payload)
      elsif intent == "GetIssueCount"
        res = get_issue_count(request_payload)
      elsif intent == "GetPublisher"
        res = get_publisher(request_payload)
      elsif intent == "GetRealName"
        res = get_real_name(request_payload)
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
  subject = req['request']['intent']['slots']['Character']['value']

  if subject == nil
    no_subject_message = "I'm not sure who you're asking about. Please " +
                         "try asking again."
    return Utils.build_res_obj(no_subject_message)
  end

  subject = Utils.handleSpecialCases(Utils.unposs(subject))
  description = ""
  attribution = ""
  pic_url = nil
  card_text = ""

  marvel_res, marvel_found = Marvel.get_character(subject)
  cv_res, cv_found = ComicVine.get_by_name(subject, "characters")
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

def get_aliases(req)
  not_found = -> subject {
    return "I could not find any aliases for #{subject}."
  }
  found = -> res {
    formatted_list = res["aliases"].split("\r\n").join(", ")
    return "#{res["name"]}'s aliases include #{formatted_list}."
  }

  return Utils.get_character_attr(req, "aliases", not_found, found)
end

def get_birth_date(req)
  not_found = -> subject {
    return "I could not find a birth date for #{subject}."
  }
  found = -> res {
    return "#{res["name"]} was born on #{res["birth"]}."
  }

  return Utils.get_character_attr(req, "birth", not_found, found)
end

def get_first_issue(req)
  not_found = -> subject {
    return "I could not find the first issue #{subject} appeared in."
  }
  found = -> res {
    issue_id = res["first_appeared_in_issue"]["id"]
    issue_url = "http://comicvine.gamespot.com/api/issue/4000-" +
                issue_id.to_s + "/"

    iss_det = ComicVine.get_detailed_info(issue_url)["results"]

    return "#{res["name"]} first appeared in #{iss_det["volume"]["name"]} " +
           "number #{iss_det["issue_number"]}: #{iss_det["name"]}, which " +
           "was dated #{iss_det["cover_date"]}."
  }

  return Utils.get_character_attr(req, "first_appeared_in_issue",
                                  not_found, found)
end

def get_issue_count(req)
  not_found = -> subject {
    return "I'm not sure how many issues #{subject} has appeared in."
  }
  found = -> res {
    return "#{res["name"]} has appeared in approximately " +
           "#{res["count_of_issue_appearances"]} issues."
  }

  return Utils.get_character_attr(req, "count_of_issue_appearances",
                                  not_found, found)
end

def get_publisher(req)
  not_found = -> subject {
    return "I could not find the publisher for #{subject}."
  }
  found = -> res {
    return "The publisher of #{res["name"]} comics is #{res["publisher"]["name"]}."
  }

  return Utils.get_character_attr(req, "publisher", not_found, found)
end

def get_real_name(req)
  not_found = -> subject {
    return "I could not find a real name for #{subject}."
  }
  found = -> res {
    return "The real name of #{res["name"]} is #{res["real_name"]}."
  }

  return Utils.get_character_attr(req, "real_name", not_found, found)
end

def end_session(req)
  return Utils.build_end_res_obj("Good-bye!")
end
