module Utils
  def Utils.get_character_attr(req, attr, not_found_mess, found_mess)
    return get_attribute(
      req,
      attr,
      "Character",
      "characters",
      not_found_mess,
      found_mess
    )
  end

  def Utils.get_attribute(req, attr, sub_slot_name, cv_resource_name,\
                          not_found_mess, found_mess)
    subject = Utils.determine_subject(req, sub_slot_name)

    if subject == nil
      no_subject_message = "I'm not sure what you're asking about. Please " +
                           "try asking again."
      return Utils.build_res_obj(no_subject_message)
    end

    cv_res, cv_found = ComicVine.get_by_name(subject, cv_resource_name)

    sessionAttributes = { "subject" => subject }

    if !cv_found || cv_res[attr] == nil
      message = not_found_mess.call(subject)
      return Utils.build_res_obj(message, sessionAttributes)
    else
      message, sess_attr = found_mess.call(cv_res)

      if sess_attr != nil
        sessionAttributes = sessionAttributes.merge(sess_attr)
      end

      return Utils.build_res_obj(message, sessionAttributes)
    end
  end

  # Will return nil if no subject is found.
  def Utils.determine_subject(req, slot_name)
    slot_value = req['request']['intent']['slots'][slot_name]['value']

    saved_subject = nil
    if req["session"]["attributes"] != nil
      saved_subject = req["session"]["attributes"]["subject"]
    end

    if slot_value == nil && saved_subject == nil
      subject = nil
    elsif slot_value == nil
      subject = saved_subject
    else
      subject = handleSpecialCases(unposs(slot_value))
    end

    return subject
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

    return subject
  end
end
