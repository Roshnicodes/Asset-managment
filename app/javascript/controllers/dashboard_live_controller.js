import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clock", "greeting"]

  connect() {
    this.update()
    this.timer = setInterval(() => this.update(), 1000)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  update() {
    const now = new Date()
    const hour = now.getHours()

    if (this.hasClockTarget) {
      this.clockTarget.textContent = now.toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit"
      })
    }

    if (this.hasGreetingTarget) {
      let greeting = "Good evening"
      if (hour < 12) greeting = "Good morning"
      else if (hour < 17) greeting = "Good afternoon"
      this.greetingTarget.textContent = greeting
    }
  }
}
