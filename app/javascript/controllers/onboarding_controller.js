import { Controller } from "@hotwired/stimulus"

// /welcome: suggestion buttons add their keyword to the keywords box, and the
// step a user reaches is sent to Google Analytics.
export default class extends Controller {
  static targets = ["keywords"]

  connect() {
    window.gtag?.("event", "onboarding_view")
  }

  addKeyword(event) {
    const keyword = event.currentTarget.dataset.keyword
    const current = this.keywordsTarget.value.split(",").map((k) => k.trim()).filter(Boolean)
    if (!current.some((k) => k.toLowerCase() === keyword.toLowerCase())) current.push(keyword)
    this.keywordsTarget.value = current.join(", ")
    event.currentTarget.classList.add("hidden")
    this.keywordsTarget.focus()
  }

  submit() {
    window.gtag?.("event", "onboarding_submit")
  }

  skip() {
    window.gtag?.("event", "onboarding_skip")
  }
}
