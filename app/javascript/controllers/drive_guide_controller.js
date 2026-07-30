import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startButton", "status", "guide", "retrySpeechButton", "simulationLocation", "simulationButton"]

  connect() {
    this.guideText = null
    this.isRequesting = false
  }

  start() {
    if (this.isRequesting) return

    if (!this.geolocationAvailable()) {
      this.showError("このブラウザでは位置情報を利用できません。")
      return
    }

    this.beginRequest()
    this.setStatus("現在地を取得しています…")

    navigator.geolocation.getCurrentPosition(
      (position) => this.requestGuide(position.coords),
      (error) => this.handleLocationError(error),
      { enableHighAccuracy: true, timeout: 10_000, maximumAge: 0 }
    )
  }

  startSimulation() {
    if (this.isRequesting) return

    const [latitude, longitude] = this.simulationLocationTarget.value.split(",").map(Number)

    this.beginRequest()
    this.setStatus("シミュレーション地点でガイドを準備しています…")
    this.requestGuide({ latitude, longitude })
  }

  async requestGuide(coords) {
    this.setStatus("ガイドを準備しています…")
    const abortController = new AbortController()
    const timeoutId = window.setTimeout(() => abortController.abort(), 30_000)

    try {
      const response = await fetch("/api/drive_guides", {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
        },
        body: JSON.stringify({ latitude: coords.latitude, longitude: coords.longitude }),
        signal: abortController.signal
      })
      const payload = await response.json()

      if (!response.ok) throw new Error(payload.error || "ガイドを取得できませんでした。")

      this.guideText = payload.guide
      this.guideTarget.textContent = payload.guide
      this.guideTarget.hidden = false
      this.setStatus(payload.location ? `${payload.location}付近のガイドです。` : "ガイドを表示しました。")
      this.speakGuide()
    } catch (error) {
      const message = error.name === "AbortError" ? "ガイドの準備に時間がかかっています。もう一度お試しください。" : error.message
      this.showError(message || "通信に失敗しました。")
    } finally {
      window.clearTimeout(timeoutId)
      this.finishRequest()
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
    this.finishRequest()
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
  }

  beginRequest() {
    this.isRequesting = true
    this.startButtonTarget.disabled = true
    if (this.hasSimulationButtonTarget) this.simulationButtonTarget.disabled = true
    this.retrySpeechButtonTarget.hidden = true
  }

  finishRequest() {
    this.isRequesting = false
    this.startButtonTarget.disabled = false
    if (this.hasSimulationButtonTarget) this.simulationButtonTarget.disabled = false
  }
}
