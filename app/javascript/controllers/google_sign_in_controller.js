import { Controller } from "@hotwired/stimulus"

// Sign in with Google without leaving the page: One Tap, plus Google's button
// in each "button" target. Returning users are signed in automatically.
// Google posts nothing to us itself; we send the ID token to Users::GoogleSignInsController.
// https://developers.google.com/identity/gsi/web/reference/js-reference
export default class extends Controller {
  static targets = ["button"]
  static values = { clientId: String, url: String, returnHere: Boolean }

  connect() {
    // If Google's script is blocked, the buttons keep their redirect-flow fallback
    loadGoogleScript().then(() => this.setup(), () => {})
  }

  setup() {
    const gsi = google.accounts.id
    gsi.initialize({
      client_id: this.clientIdValue,
      callback: ({ credential }) => this.signIn(credential),
      auto_select: true,
      cancel_on_tap_outside: false,
      context: "signin",
      itp_support: true,
      use_fedcm_for_prompt: true,
    })

    // Set by Users::SessionsController#destroy: don't sign straight back in
    if (document.cookie.split("; ").includes("signed_out=1")) {
      gsi.disableAutoSelect()
      document.cookie = "signed_out=; Max-Age=0; path=/"
    }

    for (const el of this.buttonTargets) {
      const width = Math.min(Math.max(el.offsetWidth, 240), 400)
      el.replaceChildren()
      gsi.renderButton(el, { theme: "outline", size: "large", text: "continue_with", shape: "pill", width })
    }
    gsi.prompt()
  }

  async signIn(credential) {
    // Double-submit CSRF token: see Users::GoogleSignInsController
    const csrf = crypto.randomUUID()
    document.cookie = `g_csrf_token=${csrf}; path=/; SameSite=Strict; Secure`
    const here = location.pathname + location.search
    const body = new URLSearchParams({ credential, g_csrf_token: csrf })
    if (this.returnHereValue) body.set("return_to", here)

    const response = await fetch(this.urlValue, { method: "POST", body, headers: { Accept: "application/json" } })
    const data = await response.json().catch(() => ({}))
    if (!response.ok) return showError(data.error || "Google sign-in failed, please try again.")

    // reload() revalidates; navigating to the same URL could show the
    // browser's cached logged-out copy of the page
    if (data.redirect === here) location.reload()
    else location.assign(data.redirect)
  }
}

let googleScript
function loadGoogleScript() {
  googleScript ||= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = "https://accounts.google.com/gsi/client"
    script.async = true
    script.onload = resolve
    script.onerror = reject
    document.head.append(script)
  })
  return googleScript
}

function showError(text) {
  if (window.Swal) Swal.fire({ icon: "error", text })
  else alert(text)
}
