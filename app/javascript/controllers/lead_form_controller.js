import { Controller } from "@hotwired/stimulus"

// On a hidden field in the lead forms (leads/_bot_checks): when the form is
// sent, records how long the page was open, as fill_ms. People take longer
// than a few seconds; bots that solve the captcha send at once, and scripts
// that post the form directly send nothing (SpamFilter.reason).
export default class extends Controller {
  connect() {
    this.openedAt = Date.now()
    this.record = () => { this.element.value = String(Date.now() - this.openedAt) }
    this.element.form?.addEventListener("submit", this.record)
  }

  disconnect() {
    this.element.form?.removeEventListener("submit", this.record)
  }
}
