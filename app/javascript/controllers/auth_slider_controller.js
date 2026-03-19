import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "dot"]
  static values = { interval: Number }

  connect() {
    this.index = 0
    this.show(this.index)
    this.start()
  }

  disconnect() {
    this.stop()
  }

  goTo(event) {
    this.index = Number(event.params.index)
    this.show(this.index)
    this.restart()
  }

  start() {
    this.stop()
    this.timer = setInterval(() => {
      this.index = (this.index + 1) % this.slideTargets.length
      this.show(this.index)
    }, this.intervalValue || 3500)
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
  }

  restart() {
    this.start()
  }

  show(index) {
    this.slideTargets.forEach((slide, slideIndex) => {
      slide.classList.toggle("is-active", slideIndex === index)
    })

    this.dotTargets.forEach((dot, dotIndex) => {
      dot.classList.toggle("is-active", dotIndex === index)
    })
  }
}
