module Utils
  def Utils.get_character_attr(req, attr, not_found_mess, found_mess)
    subject = Utils.determine_subject(req, "Character")
    cv_res, cv_found = ComicVine.get_by_name(subject, "characters")

    if !cv_found || cv_res[attr] == nil
      message = not_found_mess.call(subject)
      return Utils.build_res_obj(message)
    else
      message = found_mess.call(cv_res)
      return Utils.build_res_obj(message)
    end
  end

  def Utils.determine_subject(req, slot_name)
    slot_value = req['request']['intent']['slots'][slot_name]['value']

    saved_subject = nil
    if req["session"]["attributes"] != nil
      saved_subject = req["session"]["attributes"]["subject"]
    end

    if slot_value == nil && saved_subject == nil
      no_subject_message = "I'm not sure what you're asking about. Please " +
                           "try asking again."
      return build_res_obj(no_subject_message)
    elsif slot_value == nil
      subject = saved_subject
    else
      subject = unposs(slot_value)
    end

    return subject
  end

  # Everything but speech_text is optional.
  # If only one parameter (speech_text) is passed, there will be no card.
  # If nothing is passed for card_text it will be the same as speech_text.
  # For no card text, pass an empty string.
  def Utils.build_res_obj(speech_text, subject = nil, card_title = nil,\
                          attribution = "", card_image = nil, card_text = nil)
    res = {
      "version" => "1.0",
      "response" => {
        "outputSpeech" => {
          "type" => "PlainText",
          "text" => speech_text
        },
        "shouldEndSession" => false
      }
    }

    if subject
      res["sessionAttributes"] = {
        "subject" => subject
      }
    end

    if card_title
      res["response"]["card"] = { "title" => card_title }

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
end
