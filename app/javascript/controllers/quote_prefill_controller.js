import { Controller } from "@hotwired/stimulus"

// Product pages: "Request this configuration" on a card fills the quote form's
// specifications with that card's values, records which card it was, and
// takes the visitor to the form (products/show, products/_quote_form).
export default class extends Controller {
  static targets = ["details", "configuration", "quantity", "card"]

  choose({ params: { name, text }, currentTarget }) {
    if (!this.hasDetailsTarget) return // the form is replaced by "Request received"

    this.detailsTarget.value = text
    if (this.hasConfigurationTarget) this.configurationTarget.value = name
    this.cardTargets.forEach((card) => card.querySelector("button[aria-pressed]")?.setAttribute("aria-pressed", "false"))
    currentTarget.setAttribute("aria-pressed", "true")

    document.getElementById("quote")?.scrollIntoView({ behavior: "smooth", block: "start" })
    const field = this.hasQuantityTarget && !this.quantityTarget.value ? this.quantityTarget : this.detailsTarget
    field.focus({ preventScroll: true })
    window.gtag?.("event", "quote_configuration", { configuration: name || "help me choose" })
  }
}
