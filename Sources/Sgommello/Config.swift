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
        "GRRR… conta i tuoi ultimi pixel",
        "ma sei coraggioso o solo incosciente?"
    ]
    /// Said (almost kindly) when the webcam sees the user actually stand up.
    static let calmPhrases = [
        "e bravo… vai, sgranchisciti. ci vediamo dopo",
        "così si fa. torno quando ti risiedi, promesso",
        "finalmente! vai vai, il monitor resta qui"
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
