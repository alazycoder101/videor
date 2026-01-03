import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "progress", "hidden", "status"]
  static values = {
    presignUrl: { type: String, default: "/uploads/presign" },
    purpose: String
  }

  start(event) {
    const file = event.target.files[0]
    if (!file) {
      this.reset()
      return
    }

    this.toggleInput(false)
    this.showStatus("Requesting upload slot…", "text-slate-500")

    this.requestPresign(file)
      .then((signature) => this.uploadToStorage(file, signature))
      .then((key) => {
        this.hiddenTarget.value = key
        this.dispatch("complete", { detail: { key, purpose: this.purposeValue } })
        this.showStatus("Upload complete", "text-emerald-600")
      })
      .catch((error) => {
        console.error(error)
        this.hiddenTarget.value = ""
        this.showStatus(error.message || "Upload failed", "text-rose-600")
        this.dispatch("reset")
      })
      .finally(() => {
        this.toggleInput(true)
      })
  }

  reset() {
    this.inputTarget.value = ""
    this.hiddenTarget.value = ""
    this.progressTarget.value = 0
    this.hideStatus()
    this.dispatch("reset")
  }

  async requestPresign(file) {
    const response = await fetch(this.presignUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({
        upload: {
          filename: file.name,
          content_type: file.type,
          byte_size: file.size,
          purpose: this.purposeValue
        }
      })
    })

    if (!response.ok) {
      const details = await response.json().catch(() => ({}))
      throw new Error(details.error || "Unable to sign upload")
    }

    return response.json()
  }

  uploadToStorage(file, signature) {
    return new Promise((resolve, reject) => {
      const formData = new FormData()
      Object.entries(signature.fields).forEach(([key, value]) => formData.append(key, value))
      formData.append("file", file)

      const xhr = new XMLHttpRequest()
      xhr.open("POST", signature.url, true)

      xhr.upload.addEventListener("progress", (event) => {
        if (!event.lengthComputable) return
        const percent = Math.round((event.loaded / event.total) * 100)
        this.progressTarget.value = percent
      })

      xhr.onerror = () => reject(new Error("Network error during upload"))
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve(signature.fields.key)
        } else {
          reject(new Error("Storage rejected the file"))
        }
      }

      xhr.send(formData)
    })
  }

  toggleInput(enabled) {
    this.inputTarget.disabled = !enabled
    this.inputTarget.classList.toggle("opacity-60", !enabled)
  }

  showStatus(message, klass) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("hidden", "text-slate-500", "text-rose-600", "text-emerald-600")
    this.statusTarget.classList.add(klass)
  }

  hideStatus() {
    if (this.hasStatusTarget) this.statusTarget.classList.add("hidden")
  }

  get csrfToken() {
    const tokenTag = document.querySelector("meta[name='csrf-token']")
    return tokenTag ? tokenTag.content : ""
  }
}
