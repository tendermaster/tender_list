import { Controller } from "@hotwired/stimulus"

// The Save button on tender cards and pages (tenders/_bookmark_button). The
// button changes at once and changes back if the request fails. Signed-out
// visitors go to sign in, and come back to this page.
export default class extends Controller {
  static targets = ["label"]
  static values = { url: String, saved: Boolean, signedIn: Boolean, signInUrl: String, removeCard: Boolean }

  async toggle(event) {
    event.preventDefault()
    if (!this.signedInValue) {
      window.location.assign(this.signInUrlValue)
      return
    }

    const save = !this.savedValue
    this.savedValue = save
    try {
      const response = await fetch(this.urlValue, {
        method: save ? "POST" : "DELETE",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken },
        credentials: "same-origin",
      })
      if (response.status === 401) return window.location.assign(this.signInUrlValue)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      window.gtag?.("event", save ? "bookmark_add" : "bookmark_remove")
      if (!save && this.removeCardValue) this.element.closest("[data-bookmark-card]")?.remove()
    } catch {
      this.savedValue = !save
      window.alert("Couldn't update your saved tenders. Please try again.")
    }
  }

  savedValueChanged() {
    this.element.setAttribute("aria-pressed", String(this.savedValue))
    this.element.classList.toggle("is-saved", this.savedValue)
    if (this.hasLabelTarget) this.labelTarget.textContent = this.savedValue ? "Saved" : "Save"
  }

  get csrfToken() {
    return document.querySelector("meta[name=csrf-token]")?.content ?? ""
  }
}
