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

      res = Timeout::timeout(7) {
        intent_handler(request_payload)
      }

      puts "OUTPUT\n"
      puts res
      return res
    # SessionEndedRequest
    else
      puts "Session Ended."
      return Utils.build_end_res_obj("Goodbye!")
    end
  rescue Timeout::Error => e
    puts "Timeout!" + e.message
    message = "I can't get that information for you right now. What else " +
              "would you like to know?"
    return Utils.build_res_obj(message)
  rescue => e
    puts "ERROR\n" + e.message
    puts e.backtrace

    message = "I'm sorry, there was an error in this skill. Good-bye!"
    return Utils.build_end_res_obj(message)
  end
end

def intent_handler(req)
  # Get intent, send to appropriate method.
  intent = req['request']['intent']['name']

  if intent == "GetBasicInfo"
    res = get_basic_info(req)
  elsif intent == "GetAliases"
    res = get_aliases(req)
  elsif intent == "GetBirthDate"
    res = get_birth_date(req)
  elsif intent == "GetFirstIssue"
    res = get_first_issue(req)
  elsif intent == "GetIssueCount"
    res = get_issue_count(req)
  elsif intent == "GetMembers"
    res = get_members(req)
  elsif intent == "GetPowers"
    res = get_powers(req)
  elsif intent == "GetPublisher"
    res = get_publisher(req)
  elsif intent == "GetRealName"
    res = get_real_name(req)
  elsif intent == "GetTeams"
    res = get_teams(req)
  elsif intent == "AMAZON.YesIntent"
    res = yes_intent(req)
  elsif intent == "AMAZON.NoIntent"
    res = no_intent(req)
  elsif intent == "AMAZON.StopIntent" || intent == "AMAZON.CancelIntent"
    res = end_session(req)
  else
    message = "This skill is incorrectly configured. Please contact the " +
              "skill creator. Good-bye!"
    res = Utils.build_end_res_obj(message)
  end

  return res
end

def get_basic_info(req)
  subject = nil
  if req['request']['intent']['slots']['Character'] != nil
    subject = req['request']['intent']['slots']['Character']['value']
  end
  if subject == nil && req['request']['intent']['slots']['Team'] != nil
    subject = req['request']['intent']['slots']['Team']['value']
  end
  if subject == nil && req['request']['intent']['slots']['Location'] != nil
    subject = req['request']['intent']['slots']['Location']['value']
  end
  if subject == nil && req['request']['intent']['slots']['Object'] != nil
    subject = req['request']['intent']['slots']['Object']['value']
  end

  if subject == nil
    no_subject_message = "I'm not sure who you're asking about. Please " +
                         "try asking again."
    return Utils.build_res_obj(no_subject_message)
  end

  subject = Utils.handleSpecialCases(Utils.unposs(subject))
  subject = subject.split.map(&:capitalize).join(' ')

  description = ""

  marvel_res, marvel_found = Marvel.get_character(subject)
  cv_res, cv_found, resource_type = ComicVine.search(subject)

  # Review results from APIs, and decide what to return.
  card = { "title" => subject }
  ## No Results
  if !marvel_found && !cv_found
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
  card["attribution"] = "Sources:\n"
  if marvel_found
    card["attribution"] += marvel_res["attributionText"] +
                           " | http://marvel.com\n"
  end
  if cv_found
    card["attribution"] += "Comic Vine | http://comicvine.gamespot.com\n"
  end
  ## Picture
  if marvel_found && marvel_res["data"]["results"][0]["thumbnail"] != nil
    card["image"] = marvel_res["data"]["results"][0]["thumbnail"]["path"] +
              "/standard_fantastic." +
              marvel_res["data"]["results"][0]["thumbnail"]["extension"]
  end
  # Turn http to https
  if card["image"] != nil && !(card["image"].start_with?("https"))
    card["image"] = "https" + card["image"][4..-1]
  end
  ## Card Text
  if cv_found

    card["text"] = description + "\n---\n"

    unless cv_res["birth"] == nil
      card["text"] += "Born: " + cv_res["birth"] + "\n"
    end

    unless cv_res["count_of_issue_appearances"] == nil
      card["text"] += "Issue Appearances: " +
                      cv_res["count_of_issue_appearances"].to_s + "\n"
    end

    unless cv_res["publisher"] == nil
      card["text"] += "Publisher: " + cv_res["publisher"]["name"] + "\n"
    end

    unless cv_res["real_name"] == nil
      card["text"] += "Real Name: " + cv_res["real_name"] + "\n"
    end

    unless cv_res["aliases"] == nil
      card["text"] += "---\nAliases: " +
                      cv_res["aliases"].split(/\r\n|\n/).join(", ") +
                      "\n"
    end

    unless cv_res["powers"] == nil
      pow_arr = []
      cv_res["powers"].each { |power|
        pow_arr << power["name"]
      }
      card["text"] += "---\nPowers: " + pow_arr.join(", ") + "\n"
    end

    unless cv_res["teams"] == nil
      team_arr = []
      cv_res["teams"].each { |team|
        team_arr << team["name"]
      }
      card["text"] += "---\nTeams: " + team_arr.join(", ") + "\n"
    end

  end

  if resource_type != nil
    resource_type = resource_type + "s"
  end

  sessionAttributes = {
    "subject" => subject,
    "obj" => cv_res,
    "resource_type" => resource_type
  }

  if cv_found && cv_res.to_json.to_s.bytesize > 12000
    sessionAttributes["obj"] = nil
  end

  return Utils.build_res_obj(description, sessionAttributes, card)
end

def get_aliases(req)
  not_found = -> subject, resource_type {
    return "I could not find any aliases for #{subject}."
  }
  found = -> res, resource_type {
    alia_arr = res["aliases"].split(/\r\n|\n/)
    sess_attr = {}

    if alia_arr.size > 5
      if resource_type == "characters"
        say_now = "#{res["name"]}'s aliases include #{alia_arr[0]}, " +
                  "#{alia_arr[1]}, #{alia_arr[2]}, and #{alia_arr.size - 3} " +
                  "more. Would you like to hear the rest?"
      else
        say_now = "Aliases for #{res["name"]} include #{alia_arr[0]}, " +
                  "#{alia_arr[1]}, #{alia_arr[2]}, and #{alia_arr.size - 3} " +
                  "more. Would you like to hear the rest?"
      end

      rest_except_last = alia_arr[3..(alia_arr.size-2)].join(", ")
      last_alias = alia_arr[alia_arr.size-1]

      if resource_type == "teams"
        extra_info = "#{res["name"]} have also been called " +
                     "#{rest_except_last}, and #{last_alias}."
      else
        extra_info = "#{res["name"]} has also been called " +
                     "#{rest_except_last}, and #{last_alias}."
      end

      sess_attr["extraInfo"] = extra_info
      return say_now, sess_attr
    else
      formatted_list = alia_arr.join(", ")

      if resource_type == "characters"
        return "#{res["name"]}'s aliases include #{formatted_list}."
      else
        return "Aliases for #{res["name"]} include #{formatted_list}."
      end
    end
  }

  return Utils.get_attribute(req, "aliases", not_found, found)
end

def get_birth_date(req)
  not_found = -> subject, resource_type {
    return "I could not find a birth date for #{subject}."
  }
  found = -> res, resource_type {
    return "#{res["name"]} was born on #{res["birth"]}."
  }

  return Utils.get_attribute(req, "birth", not_found, found)
end

def get_first_issue(req)
  not_found = -> subject, resource_type {
    return "I could not find the first issue #{subject} appeared in."
  }
  found = -> res, resource_type {
    issue_id = res["first_appeared_in_issue"]["id"]
    issue_url = "http://comicvine.gamespot.com/api/issue/4000-" +
                issue_id.to_s + "/"

    iss_det = ComicVine.get_detailed_info(issue_url)["results"]

    return "#{res["name"]} first appeared in #{iss_det["volume"]["name"]} " +
           "number #{iss_det["issue_number"]}: #{iss_det["name"]}, which " +
           "was dated #{iss_det["cover_date"]}."
  }

  return Utils.get_attribute(req, "first_appeared_in_issue",
                                  not_found, found)
end

def get_issue_count(req)
  not_found = -> subject, resource_type {
    return "I'm not sure how many issues #{subject} has appeared in."
  }
  found = -> res, resource_type {
    return "#{res["name"]} has appeared in approximately " +
           "#{res["count_of_issue_appearances"]} issues."
  }

  return Utils.get_attribute(req, "count_of_issue_appearances",
                                  not_found, found)
end

def get_members(req)
  not_found = -> subject, resource_type {
    return "I could not find any members for #{subject}."
  }
  found = -> res, resource_type {
    sess_attr = {}
    member_arr = []
    res["characters"].each { |member|
      member_arr << member["name"]
    }

    if member_arr.size > 40
      message = "#{res["name"]} have had #{member_arr.size} members, " +
                "including #{member_arr[0]}, #{member_arr[1]}, and " +
                "#{member_arr[2]}."
      return message
    elsif member_arr.size > 5
      say_now = "Members of #{res["name"]} include #{member_arr[0]}, " +
                "#{member_arr[1]}, #{member_arr[2]}, and #{member_arr.size} " +
                "more. Would you like to hear the rest?"
      rest_except_last = member_arr[3..(member_arr.size-2)].join(", ")
      extra_info = "Other members of #{res["name"]} include " +
                   "#{rest_except_last}, and #{member_arr.last}."
      sess_attr["extraInfo"] = extra_info
      return say_now, sess_attr
    else
      formatted_list = member_arr.join(", ")
      return "Members of #{res["name"]} include #{formatted_list}."
    end
  }

  return Utils.get_attribute(req, "characters", not_found, found)
end

def get_powers(req)
  not_found = -> subject, resource_type {
    return "I could not find any powers for #{subject}."
  }
  found = -> res, resource_type {
    pow_arr = []
    res["powers"].each { |power|
      pow_arr << power["name"]
    }

    sess_attr = {}

    if pow_arr.size > 5
      say_now = "#{res["name"]}'s powers include #{pow_arr[0]}, " +
                "#{pow_arr[1]}, #{pow_arr[2]}, and #{pow_arr.size - 3} " +
                "more. Would you like to hear the rest?"
      rest_except_last = pow_arr[3..(pow_arr.size-2)].join(", ")
      last_power = pow_arr[pow_arr.size-1]
      extra_info = "Other powers of #{res["name"]} include " +
                   "#{rest_except_last}, and #{last_power}."

      sess_attr["extraInfo"] = extra_info
      return say_now, sess_attr
    else
      formatted_list = pow_arr.join(", ")
      return "#{res["name"]}'s powers include #{formatted_list}."
    end
  }

  return Utils.get_attribute(req, "powers", not_found, found)
end

def get_publisher(req)
  not_found = -> subject, resource_type {
    return "I could not find the publisher for #{subject}."
  }
  found = -> res, resource_type {
    return "The publisher of #{res["name"]} comics is #{res["publisher"]["name"]}."
  }

  return Utils.get_attribute(req, "publisher", not_found, found)
end

def get_real_name(req)
  not_found = -> subject, resource_type {
    return "I could not find a real name for #{subject}."
  }
  found = -> res, resource_type {
    return "The real name of #{res["name"]} is #{res["real_name"]}."
  }

  return Utils.get_attribute(req, "real_name", not_found, found)
end

def get_teams(req)
  not_found = -> subject, resource_type {
    return "I could not find any teams for #{subject}."
  }
  found = -> res, resource_type {
    team_arr = []
    res["teams"].each { |team|
      team_arr << team["name"]
    }

    sess_attr = {}

    if team_arr.size > 5
      say_now = "Teams #{res["name"]} has been a member of include " +
                "#{team_arr[0]}, " +
                "#{team_arr[1]}, #{team_arr[2]}, and #{team_arr.size - 3} " +
                "more. Would you like to hear the rest?"
      rest_except_last = team_arr[3..(team_arr.size-2)].join(", ")
      last_team = team_arr[team_arr.size-1]
      extra_info = "Other teams #{res["name"]} has been on include " +
                   "#{rest_except_last}, and #{last_team}."

      sess_attr["extraInfo"] = extra_info
      return say_now, sess_attr
    else
      formatted_list = team_arr.join(", ")
      return "Teams #{res["name"]} has been on include #{formatted_list}."
    end
  }

  return Utils.get_attribute(req, "teams", not_found, found)
end

def yes_intent(req)
  sess_attr = req["session"]["attributes"]

  if sess_attr == nil
    message = "What would you like to know?"
    return Utils.build_res_obj(message)
  elsif sess_attr["extraInfo"] == nil
    message = "What would you like to know?"
    return Utils.build_res_obj(message, sess_attr)
  else
    speech_text = sess_attr["extraInfo"]
    sess_attr["extraInfo"] = nil
    return Utils.build_res_obj(speech_text, sess_attr)
  end
end

def no_intent(req)
  message = "Ok. What else would you like to know?"
  if req["session"]["attributes"] != nil
    return Utils.build_res_obj(message, req["session"]["attributes"])
  else
    return Utils.build_res_obj(message)
  end
end

def end_session(req)
  return Utils.build_end_res_obj("Good-bye!")
end
