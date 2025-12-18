def get_response(message: str) -> str:
    message = message.lower()

    if "धान" in message:
        return "धान में रोग का इलाज नीम के छिड़काव से करें।"
    elif "मंडी भाव" in message:
        return "आज मंडी में गेहूं का भाव ₹2150 प्रति क्विंटल है।"
    else:
        return "आपका सवाल समझ नहीं आया। कृपया दोबारा पूछें।"
    return "यहां कोई जानकारी नहीं है। कृपया और विवरण दें।"