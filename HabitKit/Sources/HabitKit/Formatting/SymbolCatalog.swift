import Foundation

/// The symbols a habit can use, from Apple's own set. Eleven groups of twelve, each symbol in one group.
/// No group ranks above another: the picker lists them in alphabetical order in the user's language.
public enum SymbolCatalog {
    public struct Symbol: Identifiable, Sendable, Hashable {
        /// The SF Symbol name, stored on the habit.
        public let name: String
        /// What VoiceOver reads and what search matches.
        public let label: String
        /// More words search matches, for what a habit is about rather than what the symbol shows.
        public var keywords: [String] = []
        public var id: String { name }
    }

    public struct Group: Identifiable, Sendable, Hashable {
        public let key: String
        public let title: String
        public let symbols: [Symbol]
        public var id: String { key }
    }

    /// The symbols on the form's one row, after None: one for rest and one for play among them.
    /// With no analytics, "most common" is a guess.
    public static let firstRow = ["drop", "book", "moon", "dice", "figure.walk"]

    /// Every group, in alphabetical order by the user's language.
    public static var groups: [Group] {
        all.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public static var symbols: [Symbol] { all.flatMap(\.symbols) }

    public static func symbol(named name: String) -> Symbol? {
        symbols.first { $0.name == name }
    }

    /// Symbols whose label or group title holds the text, in every group.
    public static func search(_ text: String) -> [Symbol] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return symbols }
        return groups.flatMap { group in
            group.title.localizedStandardContains(query)
                ? group.symbols
                : group.symbols.filter { symbol in
                    symbol.label.localizedStandardContains(query) || symbol.keywords.contains { $0.localizedStandardContains(query) }
                }
        }
    }

    private static func s(_ name: String, _ label: String.LocalizationValue, _ keywords: String.LocalizationValue? = nil) -> Symbol {
        Symbol(
            name: name,
            label: String(localized: label, bundle: .module, comment: "A symbol's name, read by VoiceOver and matched by search"),
            keywords: keywords.map {
                String(localized: $0, bundle: .module, comment: "Search words for a symbol, separated by commas. Not shown. Use words people search for in your language. Any comma works: , or ، or ，")
                    .split(whereSeparator: { ",،，".contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) }
            } ?? []
        )
    }

    private static func g(_ key: String, _ title: String.LocalizationValue, _ symbols: [Symbol]) -> Group {
        Group(key: key, title: String(localized: title, bundle: .module, comment: "A group of symbols in the symbol picker. Short enough for a chip"), symbols: symbols)
    }

    private static var all: [Group] { [
        g("body", "Body", [
            s("pills", "Pills", "medication, medicine, meds, tablets, vitamins"), s("inhaler", "Inhaler", "asthma, medication, medicine"), s("cross.case", "First aid"), s("stethoscope", "Stethoscope"),
            s("bandage", "Bandage"), s("syringe", "Injection", "medication, medicine, insulin, jab"), s("lungs", "Lungs"), s("heart", "Heart"),
            s("hands.and.sparkles", "Washing hands", "hygiene, teeth, brushing, skincare, wash"), s("shower", "Shower", "hygiene, wash, bath"), s("calendar.badge.clock", "Appointment", "doctor, therapy, dentist"), s("bubble.left", "Talking", "therapy, journal, speak"),
        ]),
        g("food", "Food and drink", [
            s("drop", "Water", "drink, hydrate"), s("waterbottle", "Water bottle"), s("cup.and.saucer", "Cup"), s("mug", "Mug"),
            s("fork.knife", "Meal", "eat, food, breakfast, lunch, dinner"), s("carrot", "Carrot"), s("fish", "Fish"), s("frying.pan", "Cooking"),
            s("takeoutbag.and.cup.and.straw", "Takeaway"), s("basket", "Shopping basket"), s("refrigerator", "Fridge"), s("birthday.cake", "Cake"),
        ]),
        g("home", "Home", [
            s("house", "House"), s("sofa", "Sofa"), s("washer", "Washing machine", "laundry, chores"), s("dishwasher", "Dishwasher"),
            s("trash", "Bin", "chores, rubbish, recycling"), s("bubbles.and.sparkles", "Cleaning", "chores, tidy, housework"), s("wrench.and.screwdriver", "Repairs"), s("lightbulb", "Light bulb"),
            s("key", "Key"), s("dollarsign.circle", "Coin", "money, budget, saving, spending"), s("creditcard", "Card"), s("receipt", "Receipt"),
        ]),
        g("making", "Making", [
            s("pencil", "Pencil", "write, journal, draw"), s("paintbrush", "Paintbrush"), s("paintpalette", "Palette"), s("scissors", "Scissors"),
            s("hammer", "Hammer"), s("ruler", "Ruler"), s("camera", "Camera"), s("film", "Film"),
            s("pianokeys", "Piano"), s("guitars", "Guitar"), s("music.note", "Music"), s("mic", "Microphone"),
        ]),
        g("mind", "Mind", [
            s("brain", "Brain"), s("brain.head.profile", "Thinking"), s("figure.mind.and.body", "Meditation", "mindfulness, calm, breathe"), s("sunrise", "Sunrise"),
            s("flame", "Candle"), s("sparkles", "Sparkles"), s("wind", "Breathing"), s("face.smiling", "Smile"),
            s("heart.text.square", "Gratitude", "journal, thanks"), s("quote.bubble", "Quote"), s("lightbulb.max", "Idea"), s("eye", "Noticing"),
        ]),
        g("movement", "Movement", [
            s("figure.walk", "Walking", "walk, steps, exercise"), s("figure.run", "Running"), s("figure.roll", "Wheelchair"), s("bicycle", "Cycling"),
            s("dumbbell", "Weights", "gym, exercise, workout"), s("figure.yoga", "Yoga"), s("figure.pool.swim", "Swimming"), s("figure.strengthtraining.traditional", "Strength"),
            s("figure.cooldown", "Stretching", "stretch, mobility"), s("figure.stairs", "Stairs"), s("figure.core.training", "Core"), s("figure.rower", "Rowing"),
        ]),
        g("outdoors", "Outdoors", [
            s("leaf", "Leaf"), s("tree", "Tree"), s("sun.max", "Sun"), s("cloud.sun", "Sky"),
            s("mountain.2", "Mountains"), s("figure.hiking", "Hiking"), s("binoculars", "Binoculars"), s("camera.macro", "Flower"),
            s("bird", "Bird"), s("water.waves", "Water"), s("sailboat", "Boat"), s("map", "Map"),
        ]),
        g("people", "People", [
            s("person.2", "Two people"), s("person.3", "Group"), s("figure.2.and.child.holdinghands", "Family"), s("figure.2.arms.open", "Hug"),
            s("hand.wave", "Wave"), s("phone", "Phone call", "call, family, friend"), s("envelope", "Letter"), s("bubble.left.and.bubble.right", "Conversation"),
            s("gift", "Gift"), s("pawprint", "Paw"), s("dog", "Dog"), s("cat", "Cat"),
        ]),
        g("play", "Play", [
            s("gamecontroller", "Game controller"), s("dice", "Dice"), s("suit.spade", "Playing cards"), s("puzzlepiece", "Puzzle"),
            s("checkerboard.rectangle", "Board game"), s("soccerball", "Ball"), s("tennis.racket", "Racket"), s("balloon", "Balloon"),
            s("figure.socialdance", "Dancing"), s("headphones", "Headphones"), s("ticket", "Ticket"), s("tent", "Tent"),
        ]),
        g("rest", "Rest", [
            s("moon", "Moon"), s("moon.stars", "Night"), s("bed.double", "Bed", "sleep, bedtime"), s("zzz", "Sleep"),
            s("powersleep", "Nap"), s("alarm", "Alarm"), s("hourglass", "Hourglass"), s("beach.umbrella", "Beach"),
            s("bathtub", "Bath"), s("iphone.slash", "Phone away", "screen time, social media, offline"), s("sun.horizon", "Sunset"), s("cloud.moon", "Evening"),
        ]),
        g("work", "Work and study", [
            s("book", "Book", "read, reading"), s("books.vertical", "Books"), s("graduationcap", "Study"), s("character.book.closed", "Language", "learn, vocabulary"),
            s("laptopcomputer", "Laptop"), s("keyboard", "Keyboard"), s("briefcase", "Work"), s("doc.text", "Document"),
            s("folder", "Folder"), s("checklist", "Checklist"), s("calendar", "Calendar"), s("chart.bar", "Chart"),
        ]),
    ] }
}
