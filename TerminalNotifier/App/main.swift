import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(PreviewMode.current == nil ? .accessory : .regular)
app.run()
