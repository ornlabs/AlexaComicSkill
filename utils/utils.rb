module Utils
  def Utils.get_attribute(req, attr, not_found_mess, found_mess)
    subject, resource_type = Utils.determine_subject(req)

    if subject == nil
      no_subject_message = "I'm not sure what you're asking about. " +
                           "What else would you like to know?"
      return Utils.build_res_obj(no_subject_message)
    end

    saved_obj = nil

    if req["session"]["attributes"] != nil
      saved_obj = req["session"]["attributes"]["obj"]

      if saved_obj == nil || saved_obj["name"].downcase != subject.downcase
        saved_obj = nil
      end
    end

    if saved_obj != nil
      cv_found = true
      cv_res = saved_obj
    else
      cv_res, cv_found = ComicVine.get_by_name(subject, resource_type)
    end

    sessionAttributes = {
      "subject" => subject,
      "obj" => cv_res,
      "resource_type" => resource_type
    }

    if cv_found && cv_res.to_json.to_s.bytesize > 12000
      sessionAttributes["obj"] = nil
    end

    sub_to_pass = subject
    cv_res_to_pass = cv_res

    if resource_type == "teams" || resource_type == "objects"
      unless attr == "publisher"
        sub_to_pass = "The " + subject
        if cv_res != nil
          cv_res_to_pass["name"] = "The " + cv_res_to_pass["name"]
        end
      end
    end

    if !cv_found || cv_res[attr] == nil
      message = not_found_mess.call(sub_to_pass, resource_type)
      message += " What else would you like to know?"
      return Utils.build_res_obj(message, sessionAttributes)
    else
      message, sess_attr = found_mess.call(cv_res_to_pass, resource_type)

      if sess_attr != nil
        sessionAttributes = sessionAttributes.merge(sess_attr)
      end

      if sessionAttributes["extraInfo"] == nil
        message += " What else would you like to know?"
      end

      return Utils.build_res_obj(message, sessionAttributes)
    end
  end

  # Will return nil if no subject is found.
  def Utils.determine_subject(req)
    slot_value = nil
    resource_type = nil
    slots = req['request']['intent']['slots']
    if slots['Character'] != nil && slots["Character"]["value"] != nil
      slot_value = slots['Character']['value']
      resource_type = "characters"
    elsif slots['Team'] != nil && slots["Team"]["value"] != nil
      slot_value = slots['Team']['value']
      resource_type = "teams"
    elsif slots['Location'] != nil && slots["Location"]["value"] != nil
      slot_value = slots['Location']['value']
      resource_type = "locations"
    elsif slots['Object'] != nil && slots["Object"]["value"] != nil
      slot_value = slots['Object']['value']
      resource_type = "objects"
    end

    saved_subject = nil
    if req["session"]["attributes"] != nil
      saved_subject = req["session"]["attributes"]["subject"]
    end

    if slot_value == nil && saved_subject == nil
      subject = nil
    elsif slot_value == nil
      subject = saved_subject
      resource_type = req["session"]["attributes"]["resource_type"]
    else
      subject = handleSpecialCases(unposs(slot_value))
    end

    return subject, resource_type
  end

  # Everything but speech_text is optional.
  # If only one parameter (speech_text) is passed, there will be no card.
  # card = { "title" => "", "text" => "", "attribution" => "", "image" => ""}
  def Utils.build_res_obj(speech_text, sessionAttributes = {}, card = nil)
    res = {
      "version" => "1.0",
      "response" => {
        "outputSpeech" => {
          "type" => "PlainText",
          "text" => speech_text
        },
        "reprompt" => {
          "outputSpeech" => {
            "type" => "PlainText",
            "text" => "What else do you want to know?"
          }
        },
        "shouldEndSession" => false
      }
    }

    if sessionAttributes != {}
      res["sessionAttributes"] = sessionAttributes
    end

    if card != nil
      res["response"]["card"] = { "title" => card["title"] }

      if card["text"] == nil
        card_text = speech_text
      else
        card_text = card["text"]
      end

      if card["attribution"] != nil
        card_text += "---\n" + card["attribution"]
      end

      if card["image"] == nil
        res["response"]["card"]["type"] = "Simple"
        res["response"]["card"]["content"] = card_text
      else
        res["response"]["card"]["type"] = "Standard"
        res["response"]["card"]["text"] = card_text
        res["response"]["card"]["image"] = {
          "largeImageUrl" => card["image"]
        }
      end
    end

    return JSON.generate(res)
  end

  def Utils.build_end_res_obj(speech_text)
    return JSON.generate({
      "version" => "1.0",
      "response" => {
        "outputSpeech" => {
          "type" => "PlainText",
          "text" => speech_text
        },
        "shouldEndSession" => true
      }
    })
  end

  # Remove the 's or ' from the end of the passed string. (Un-poss[essive])
  def Utils.unposs(str)
    if str.end_with?("'s")
      return str[0...-2]
    elsif str.end_with?("'")
      return str[0...-1]
    end
    return str
  end

  def Utils.handleSpecialCases(subject)
    # Hack to make sure the normal/main Spider-Man/Woman/Girl is returned,
    # as Marvel and Comic Vine list their names with a hyphen.
    if subject.downcase.start_with?("spider")
      unless subject.downcase.start_with?("spider-")
        subject = subject.sub(" ", "-")
      end
      if subject.downcase == "spiderman"
        subject = "Spider-Man"
      end
    end

    # Make "Justice League" return "Justice League of America"
    if subject.downcase == "justice league"
      subject = "Justice League of America"
    end

    return subject
  end
end
