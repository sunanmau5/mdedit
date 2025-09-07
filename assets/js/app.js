// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/mdedit"
import topbar from "../vendor/topbar"

// Add keyboard shortcuts for the markdown editor
let EditorHook = {
  mounted() {
    this.el.addEventListener("keydown", (e) => {
      // Ctrl+S or Cmd+S to save document
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault()
        document.querySelector('[phx-click="save_document"]')?.click()
      }

      // Tab to insert tab character instead of focusing next element
      if (e.key === 'Tab' && !e.shiftKey) {
        e.preventDefault()
        const start = this.el.selectionStart
        const end = this.el.selectionEnd
        this.el.value = this.el.value.substring(0, start) + '\t' + this.el.value.substring(end)
        this.el.selectionStart = this.el.selectionEnd = start + 1

        // trigger change event
        this.el.dispatchEvent(new Event('input', { bubbles: true }))
      }
    })

    // Handle real-time content synchronization from other users
    this.handleEvent("sync_content", ({ content }) => {
      // preserve cursor position if possible
      const start = this.el.selectionStart
      const end = this.el.selectionEnd

      // Update content only if different to avoid cursor jumping
      if (this.el.value !== content) {
        this.el.value = content

        // Try to preserve cursor position
        const newLength = content.length
        const newStart = Math.min(start, newLength)
        const newEnd = Math.min(end, newLength)

        this.el.setSelectionRange(newStart, newEnd)
      }
    })
  }
}

// Auto-dismiss flash messages after 1 second
const FlashHook = {
  mounted() {
    // Auto-dismiss after 1 second by triggering the existing click handler
    this.timer = setTimeout(() => this.el.click(), 1000)
  },
  
  destroyed() {
    // Clear timer if component is destroyed before auto-dismiss
    clearTimeout(this.timer)
  }
}

// Admin token management for pads
const AdminTokenManager = {
  store(padId, adminToken) {
    localStorage.setItem(`admin_token_${padId}`, adminToken)
  },

  get(padId) {
    return localStorage.getItem(`admin_token_${padId}`)
  },

  clear(padId) {
    localStorage.removeItem(`admin_token_${padId}`)
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: (liveSocket) => {
    const params = {_csrf_token: csrfToken}

    // Add admin token for editor routes
    const path = window.location.pathname
    const editorMatch = path.match(/^\/editor\/([^\/]+)$/)

    if (editorMatch) {
      const slug = editorMatch[1]
      const adminToken = AdminTokenManager.get(slug)
      if (adminToken) {
        params.admin_token = adminToken
      }
    }

    return params
  },
  hooks: {
    ...colocatedHooks,
    EditorHook,
    FlashHook
  },
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// Handle copy to clipboard events
window.addEventListener("phx:copy_to_clipboard", (e) => {
  const text = e.detail.text
  navigator.clipboard.writeText(text).then(() => {
    // Successfully copied to clipboard
  }).catch(err => {
    console.error("Failed to copy to clipboard:", err)
    // Fallback for older browsers
    const textArea = document.createElement("textarea")
    textArea.value = text
    document.body.appendChild(textArea)
    textArea.select()
    document.execCommand("copy")
    document.body.removeChild(textArea)
  })
})

// Handle admin token storage events
window.addEventListener("phx:store_admin_token", (e) => {
  const { slug, admin_token } = e.detail
  AdminTokenManager.store(slug, admin_token)
  console.log("Admin token stored for document:", slug)
})

window.addEventListener("phx:clear_admin_token", (e) => {
  const { slug } = e.detail
  AdminTokenManager.clear(slug)
  console.log("Admin token cleared for document:", slug)
})

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

