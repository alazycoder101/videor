import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 4000 }
  }

  connect() {
    if (!this.hasUrlValue) return
    this.start()
  }

  disconnect() {
    this.stop()
  }

  start() {
    this.stop()
    this.refresh()
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  async refresh() {
    try {
      const response = await fetch(this.urlValue, {
        headers: { "Turbo-Frame": this.element.id }
      })
      if (!response.ok) throw new Error("Status refresh failed")
      const html = await response.text()
      this.element.innerHTML = html
    } catch (error) {
      console.warn(error)
      this.stop()
    }
  }
}
