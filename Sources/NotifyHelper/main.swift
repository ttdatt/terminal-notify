import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Set activation policy to accessory (LSUIElement behavior - no dock icon)
app.setActivationPolicy(.accessory)

app.run()
