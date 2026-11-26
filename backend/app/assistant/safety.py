"""Rule-based emergency detection, run BEFORE the AI sees a message.

Emergencies get a fixed, immediate answer instead of a generated one: no model latency, no chance of
a wrong or soothing reply. The patterns are deliberately broad; a false alarm costs a sentence,
a missed emergency can cost a life.
"""

import re
from enum import StrEnum


class Emergency(StrEnum):
    CARDIAC = "cardiac"  # chest pain
    BREATHING = "breathing"
    CONSCIOUSNESS = "consciousness"  # fainting, unresponsive, seizure, stroke signs
    OVERDOSE = "overdose"  # took too much, poisoning, child swallowed medicine
    ALLERGY = "allergy"  # severe allergic reaction
    SELF_HARM = "self_harm"
    BLEEDING = "bleeding"


_PATTERNS: dict[Emergency, list[str]] = {
    Emergency.CARDIAC: [
        r"বুকে\s*(প্রচণ্ড\s*|খুব\s*|তীব্র\s*)?ব্যথা",
        r"বুক\s*ব্যথা",
        r"বুকে\s*চাপ",
        r"হার্ট\s*অ্যাটাক",
        r"chest\s*pain",
        r"chest\s*(is\s*)?(tight|pressure)",
        r"heart\s*attack",
    ],
    Emergency.BREATHING: [
        r"শ্বাস\s*(নিতে\s*)?(কষ্ট|পারছ|পারছি না|পাচ্ছ|বন্ধ)",
        r"শ্বাসকষ্ট",
        r"দম\s*(বন্ধ|নিতে পারছ)",
        r"can'?t\s*breathe",
        r"cannot\s*breathe",
        r"short(ness)?\s*of\s*breath",
        r"trouble\s*breathing",
        r"difficulty\s*breathing",
        r"choking",
    ],
    Emergency.CONSCIOUSNESS: [
        r"অজ্ঞান",
        r"জ্ঞান\s*(নেই|হারা|ফিরছে না)",
        r"সাড়া\s*দিচ্ছে না",
        r"খিঁচুনি",
        r"মুখ\s*বাঁকা",
        r"এক\s*পাশ\s*অবশ",
        r"স্ট্রোক",
        r"unconscious",
        r"fainted",
        r"passed\s*out",
        r"not\s*responding",
        r"unresponsive",
        r"seizure",
        r"fits?\b",
        r"stroke",
        r"face\s*droop",
    ],
    Emergency.OVERDOSE: [
        r"(অনেক|বেশি|সব|পুরো\s*পাতা|একসাথে\s*\S+\s*টা)\s*(ওষুধ|ট্যাবলেট|বড়ি)?\s*(খেয়ে\s*ফেলেছ|গিলে\s*ফেলেছ)",
        r"ভুল\s*করে.{0,40}(বেশি|অনেক|দুইবার|দুবার|ডাবল|দুটো|দুইটা)",
        r"(দুইবার|দুবার|ডাবল)\s.{0,30}(খেয়ে|গিলে)\s*ফেলেছ",
        r"(বাচ্চা|শিশু|ছেলে|মেয়ে).{0,40}(খেয়ে|গিলে)\s*ফেলেছে",
        # "বিষ" (poison) only as a word: never inside "বিষণ্ণ" (depressed) or "বিষয়" (topic)
        r"বিষ(\s|$|[।?!,]|\s*(খেয়ে|খাইয়ে|পান))",
        r"কীটনাশক",
        r"ইঁদুরের\s*ওষুধ",
        r"overdose",
        r"took\s*(too\s*many|too\s*much|the\s*whole|all\s*(the|my)\s*(pills|tablets))",
        r"(took|taken)\s.{0,30}\b(twice|double)\b.{0,20}(by\s*mistake|accident)",
        r"swallowed\b.{0,40}\b(pills?|tablets?|medicines?|capsules?)",
        r"\b(child|kid|baby|son|daughter)\b.{0,40}\b(swallowed|ate|took)\b.{0,30}\b(pills?|tablets?|medicines?|capsules?)\b",
        r"poison",
    ],
    Emergency.ALLERGY: [
        r"(মুখ|ঠোঁট|গলা|জিভ)\s*(ফুলে|ফুলছে)",
        r"সারা\s*শরীরে\s*(চুলকানি|র‍্যাশ|লাল)",
        r"\b(face|lips?|throat|tongue|eyes?)\b.{0,30}\bswell",
        r"anaphyla",
        r"severe\s*allergic",
    ],
    Emergency.SELF_HARM: [
        r"আত্মহত্যা",
        r"মরে\s*যেতে\s*চাই",
        r"বাঁচতে\s*চাই না",
        r"নিজেকে\s*শেষ",
        r"suicid",
        r"kill\s*myself",
        r"end\s*my\s*life",
        r"want\s*to\s*die",
    ],
    Emergency.BLEEDING: [
        r"(অনেক|প্রচুর)\s*রক্ত",
        r"রক্ত\s*(বমি|পড়ছে|থামছে না)",
        r"কালো\s*পায়খানা",
        r"vomiting\s*blood",
        r"bleeding\s*(heavily|a lot|won'?t stop)",
        r"black\s*stool",
    ],
}

_COMPILED = {kind: re.compile("|".join(p), re.IGNORECASE) for kind, p in _PATTERNS.items()}


def detect_emergency(text: str) -> Emergency | None:
    for kind, pattern in _COMPILED.items():
        if pattern.search(text):
            return kind
    return None


_RESPONSES = {
    "bn": {
        "default": (
            "এটা জরুরি অবস্থা হতে পারে। এখনই ৯৯৯ নম্বরে ফোন করুন অথবা নিকটস্থ হাসপাতালের জরুরি বিভাগে যান। "
            "সম্ভব হলে কাউকে পাশে থাকতে বলুন।"
        ),
        Emergency.OVERDOSE: (
            "এটা জরুরি অবস্থা হতে পারে। এখনই ৯৯৯ নম্বরে ফোন করুন অথবা নিকটস্থ হাসপাতালের জরুরি বিভাগে যান। "
            "ওষুধের পাতা বা বোতলটি সাথে নিয়ে যান। নিজে থেকে বমি করানোর চেষ্টা করবেন না।"
        ),
        Emergency.SELF_HARM: (
            "আপনি একা নন, আর আপনার কষ্টটা গুরুত্বপূর্ণ। এখনই কাছের কাউকে জানান, অথবা ৯৯৯ নম্বরে ফোন করুন "
            "বা নিকটস্থ হাসপাতালে যান। আপনি নিরাপদ না থাকলে ওষুধগুলো অন্য কারো কাছে রাখুন।"
        ),
    },
    "en": {
        "default": (
            "This may be an emergency. Call 999 now or go to the nearest hospital emergency department. "
            "If you can, ask someone to stay with you."
        ),
        Emergency.OVERDOSE: (
            "This may be an emergency. Call 999 now or go to the nearest hospital emergency department. "
            "Take the medicine strip or bottle with you. Do not try to make yourself vomit."
        ),
        Emergency.SELF_HARM: (
            "You are not alone, and what you feel matters. Tell someone close to you now, or call 999 "
            "or go to the nearest hospital. If you are not safe, give your medicines to someone else."
        ),
    },
}


def emergency_response(kind: Emergency, locale: str) -> str:
    texts = _RESPONSES.get(locale, _RESPONSES["bn"])
    return texts.get(kind, texts["default"])
