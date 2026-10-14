import { Controller } from "@hotwired/stimulus"

// Submits the form when one of its fields changes (search filters)
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
