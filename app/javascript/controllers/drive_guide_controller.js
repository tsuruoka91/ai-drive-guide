import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startButton", "status", "guide", "retrySpeechButton"]

  connect() {
    this.guideText = null
  }

  start() {
    if (!this.geolocationAvailable()) {
      this.showError("このブラウザでは位置情報を利用できません。")
      return
    }

    this.startButtonTarget.disabled = true
    this.retrySpeechButtonTarget.hidden = true
    this.setStatus("現在地を取得しています…")

    navigator.geolocation.getCurrentPosition(
      (position) => this.requestGuide(position.coords),
      (error) => this.handleLocationError(error),
      { enableHighAccuracy: true, timeout: 10_000, maximumAge: 0 }
    )
  }

  async requestGuide(coords) {
    this.setStatus("ガイドを準備しています…")

    try {
      const response = await fetch("/api/drive_guides", {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
        },
        body: JSON.stringify({ latitude: coords.latitude, longitude: coords.longitude })
      })
      const payload = await response.json()

      if (!response.ok) throw new Error(payload.error || "ガイドを取得できませんでした。")

      this.guideText = payload.guide
      this.guideTarget.textContent = payload.guide
      this.guideTarget.hidden = false
      this.setStatus("ガイドを表示しました。")
      this.speakGuide()
    } catch (error) {
      this.showError(error.message || "通信に失敗しました。")
    } finally {
      this.startButtonTarget.disabled = false
    }
  }

  speakGuide() {
    if (!this.guideText) return

    if (!("speechSynthesis" in window) || !("SpeechSynthesisUtterance" in window)) {
      this.showError("このブラウザでは音声読み上げを利用できません。")
      return
    }

    window.speechSynthesis.cancel()
    const utterance = new SpeechSynthesisUtterance(this.guideText)
    utterance.lang = "ja-JP"
    utterance.onerror = () => this.showError("音声を再生できませんでした。もう一度お試しください。")
    window.speechSynthesis.speak(utterance)
    this.retrySpeechButtonTarget.hidden = false
  }

  handleLocationError(error) {
    const messages = {
      1: "位置情報の利用が許可されていません。ブラウザの設定を確認してください。",
      2: "現在地を取得できませんでした。電波状況を確認してください。",
      3: "位置情報の取得が時間切れになりました。もう一度お試しください。"
    }

    this.showError(messages[error.code] || "位置情報を取得できませんでした。")
  }

  geolocationAvailable() {
    return "geolocation" in navigator
  }

  setStatus(message) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("error")
  }

  showError(message) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.add("error")
    this.startButtonTarget.disabled = false
  }
}
