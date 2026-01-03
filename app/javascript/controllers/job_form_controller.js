import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "required"]

  connect() {
    this.refresh()
  }

  refresh() {
    if (!this.hasSubmitTarget) return

    const ready = this.requiredTargets.every((field) => field.value && field.value.length > 0)
    this.submitTarget.disabled = !ready
  }
}
