import AppKit

// MARK: - Config

enum Config {
    /// How long the user can stay continuously active before Sgommello shows up.
    /// Backed by AppSettings so it survives relaunches and can be changed from the menu.
    static var triggerInterval: TimeInterval {
        AppSettings.shared.triggerMinutes * 60
    }
    /// Idle time after which we consider the user "already took a break" and reset the counter.
    static var idleResetThreshold: TimeInterval = 60
    /// How long the cursor must stay inside the safe zone to dismiss Sgommello.
    static var safeZoneHoldTime: TimeInterval = 3
    /// Sprite render size on screen.
    static let spriteSize = CGSize(width: 140, height: 140)
    /// Shown while roaming. Rotated slowly so each one gets read.
    static let phrases = [
        "sei ancora lì? ora vengo e ti spacco la faccia! ahah",
        "ti avevo detto di staccare, eh… ora rompo tutto",
        "alzati e cammina, o il prossimo pugno è sul dock",
        "il tuo capo può aspettare. il tuo collo no.",
        "occhi rossi e schiena a pezzi… e tu ancora qui",
        "vai a farti un caffè VERO, non un altro standup",
        "conto fino a tre e poi sfondo anche la webcam",
        "lo senti? è il rumore della pausa che non fai",
        "guarda che questo monitor lo ripaghi tu"
    ]
    /// Yelled when the user clicks (pinches) him.
    static let pinchPhrases = [
        "AHIA! le mani a posto!",
        "mi hai PIZZICATO?! ora mi arrabbio davvero",
        "riprova e ti mangio il cursore",
        "conta i tuoi ultimi pixel, umano",
        "ma sei coraggioso o solo incosciente?"
    ]
    /// Said (almost kindly) when the webcam sees the user stand up: he lies
    /// down and guards the break by sleeping through it.
    static let sleepPhrases = [
        "e bravo… io intanto mi schiaccio un pisolino",
        "così si fa. io dormo, tu cammina",
        "finalmente… zzz… e non tornare presto"
    ]
    /// Snapped when the user comes back BEFORE the break is over.
    static let wakePhrases = [
        "GIÀ TORNATO?! la pausa non è mica finita!",
        "ehi! mancavano ancora dei minuti, torna fuori!",
        "ti ho visto eh! quella non era una pausa vera"
    ]
    /// Barked right as a punch lands on the screen.
    static let punchPhrases = [
        "TIÈ!",
        "BAM!",
        "e questo è per lo straordinario!",
        "ops, m'è scappato il pugno!",
        "te l'avevo detto!"
    ]
}
