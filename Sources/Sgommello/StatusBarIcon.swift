import AppKit

// MARK: - Status Bar Icon

enum StatusBarIcon {
    static func image(isActive: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.black.set()

        if isActive {
            drawActiveFace(in: NSRect(origin: .zero, size: size))
        } else {
            drawInactiveBackside(in: NSRect(origin: .zero, size: size))
        }

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = isActive ? "Sgommello attivo" : "Sgommello in pausa"
        return image
    }

    private static func drawActiveFace(in rect: NSRect) {
        let head = NSBezierPath(roundedRect: NSRect(x: 4.1, y: 3.3, width: 13.8, height: 14.4),
                                xRadius: 5.0,
                                yRadius: 5.4)
        head.lineWidth = 1.65
        head.stroke()

        let leftHorn = NSBezierPath()
        leftHorn.move(to: NSPoint(x: 6.1, y: 16.2))
        leftHorn.line(to: NSPoint(x: 4.4, y: 19.0))
        leftHorn.line(to: NSPoint(x: 7.9, y: 17.4))
        leftHorn.lineWidth = 1.45
        leftHorn.lineCapStyle = .round
        leftHorn.lineJoinStyle = .round
        leftHorn.stroke()

        let rightHorn = NSBezierPath()
        rightHorn.move(to: NSPoint(x: 15.9, y: 16.2))
        rightHorn.line(to: NSPoint(x: 17.6, y: 19.0))
        rightHorn.line(to: NSPoint(x: 14.1, y: 17.4))
        rightHorn.lineWidth = 1.45
        rightHorn.lineCapStyle = .round
        rightHorn.lineJoinStyle = .round
        rightHorn.stroke()

        let leftBrow = NSBezierPath()
        leftBrow.move(to: NSPoint(x: 7.0, y: 12.4))
        leftBrow.line(to: NSPoint(x: 9.3, y: 11.7))
        leftBrow.lineWidth = 1.25
        leftBrow.lineCapStyle = .round
        leftBrow.stroke()

        let rightBrow = NSBezierPath()
        rightBrow.move(to: NSPoint(x: 15.0, y: 12.4))
        rightBrow.line(to: NSPoint(x: 12.7, y: 11.7))
        rightBrow.lineWidth = 1.25
        rightBrow.lineCapStyle = .round
        rightBrow.stroke()

        NSBezierPath(ovalIn: NSRect(x: 7.4, y: 9.7, width: 1.65, height: 1.9)).fill()
        NSBezierPath(ovalIn: NSRect(x: 13.0, y: 9.7, width: 1.65, height: 1.9)).fill()

        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 10.6, y: 9.1))
        nose.line(to: NSPoint(x: 10.0, y: 8.0))
        nose.line(to: NSPoint(x: 11.2, y: 8.0))
        nose.lineWidth = 1.0
        nose.lineCapStyle = .round
        nose.lineJoinStyle = .round
        nose.stroke()

        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: 8.5, y: 6.8))
        mouth.curve(to: NSPoint(x: 13.5, y: 6.8),
                    controlPoint1: NSPoint(x: 9.7, y: 4.8),
                    controlPoint2: NSPoint(x: 12.3, y: 4.8))
        mouth.curve(to: NSPoint(x: 8.5, y: 6.8),
                    controlPoint1: NSPoint(x: 12.6, y: 8.5),
                    controlPoint2: NSPoint(x: 9.4, y: 8.5))
        mouth.close()
        mouth.lineWidth = 1.25
        mouth.stroke()

        let tongue = NSBezierPath()
        tongue.move(to: NSPoint(x: 9.7, y: 6.0))
        tongue.curve(to: NSPoint(x: 12.3, y: 6.0),
                     controlPoint1: NSPoint(x: 10.5, y: 5.3),
                     controlPoint2: NSPoint(x: 11.5, y: 5.3))
        tongue.lineWidth = 1.0
        tongue.lineCapStyle = .round
        tongue.stroke()

        NSColor.black.set()
    }

    private static func drawInactiveBackside(in rect: NSRect) {
        let body = NSBezierPath()
        body.move(to: NSPoint(x: 5.1, y: 6.2))
        body.curve(to: NSPoint(x: 6.2, y: 14.7),
                   controlPoint1: NSPoint(x: 3.4, y: 9.5),
                   controlPoint2: NSPoint(x: 3.8, y: 13.0))
        body.curve(to: NSPoint(x: 11.0, y: 17.0),
                   controlPoint1: NSPoint(x: 7.7, y: 16.0),
                   controlPoint2: NSPoint(x: 9.3, y: 17.0))
        body.curve(to: NSPoint(x: 15.8, y: 14.7),
                   controlPoint1: NSPoint(x: 12.7, y: 17.0),
                   controlPoint2: NSPoint(x: 14.3, y: 16.0))
        body.curve(to: NSPoint(x: 16.9, y: 6.2),
                   controlPoint1: NSPoint(x: 18.2, y: 13.0),
                   controlPoint2: NSPoint(x: 18.6, y: 9.5))
        body.lineWidth = 1.8
        body.lineCapStyle = .round
        body.lineJoinStyle = .round
        body.stroke()

        let leftCheek = NSBezierPath(ovalIn: NSRect(x: 4.9, y: 5.0, width: 6.8, height: 7.6))
        leftCheek.lineWidth = 1.45
        leftCheek.stroke()

        let rightCheek = NSBezierPath(ovalIn: NSRect(x: 10.3, y: 5.0, width: 6.8, height: 7.6))
        rightCheek.lineWidth = 1.45
        rightCheek.stroke()

        let crease = NSBezierPath()
        crease.move(to: NSPoint(x: 11.0, y: 13.2))
        crease.curve(to: NSPoint(x: 11.0, y: 5.9),
                     controlPoint1: NSPoint(x: 10.3, y: 11.2),
                     controlPoint2: NSPoint(x: 11.7, y: 8.1))
        crease.lineWidth = 1.35
        crease.lineCapStyle = .round
        crease.stroke()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 15.9, y: 14.3))
        tail.curve(to: NSPoint(x: 18.4, y: 16.2),
                   controlPoint1: NSPoint(x: 17.4, y: 14.3),
                   controlPoint2: NSPoint(x: 18.7, y: 14.9))
        tail.curve(to: NSPoint(x: 16.4, y: 17.0),
                   controlPoint1: NSPoint(x: 18.1, y: 17.3),
                   controlPoint2: NSPoint(x: 17.1, y: 17.3))
        tail.lineWidth = 1.45
        tail.lineCapStyle = .round
        tail.stroke()

        let leftFoot = NSBezierPath()
        leftFoot.move(to: NSPoint(x: 6.0, y: 4.2))
        leftFoot.line(to: NSPoint(x: 8.4, y: 4.2))
        leftFoot.lineWidth = 1.5
        leftFoot.lineCapStyle = .round
        leftFoot.stroke()

        let rightFoot = NSBezierPath()
        rightFoot.move(to: NSPoint(x: 13.6, y: 4.2))
        rightFoot.line(to: NSPoint(x: 16.0, y: 4.2))
        rightFoot.lineWidth = 1.5
        rightFoot.lineCapStyle = .round
        rightFoot.stroke()
    }
}
