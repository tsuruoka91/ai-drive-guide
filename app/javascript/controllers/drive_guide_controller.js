import { Controller } from "@hotwired/stimulus"

const IIZUKA_CAMPUS = { latitude: 33.65409392, longitude: 130.67159183 }

export default class extends Controller {
  static targets = ["startButton", "status", "guide", "retrySpeechButton", "simulationLocation", "simulationButton", "map", "mapNotice", "mapSimulationButton"]
  static values = { development: Boolean, googleMapsApiKey: String }

  connect() {
    this.guideText = null
    this.isRequesting = false
    this.googleMapsLoadingPromise = null

    if (this.developmentValue && this.googleMapsApiKeyValue) {
      this.updateMap(IIZUKA_CAMPUS, { markerTitle: "九州工業大学飯塚キャンパス（シミュレーション初期位置）" })
    }
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
      (position) => {
        this.updateMap(position.coords)
        this.requestGuide(position.coords)
      },
      (error) => this.handleLocationError(error),
      { enableHighAccuracy: true, timeout: 10_000, maximumAge: 0 }
    )
  }

  startSimulation() {
    if (this.isRequesting) return

    const [latitude, longitude] = this.simulationLocationTarget.value.split(",").map(Number)

    this.beginRequest()
    this.setStatus("シミュレーション地点でガイドを準備しています…")
    const coords = { latitude, longitude }
    this.updateMap(coords)
    this.requestGuide(coords)
  }

  startMapSimulation() {
    if (this.isRequesting || !this.map) return

    const center = this.map.getCenter()
    const coords = { latitude: center.lat(), longitude: center.lng() }

    this.beginRequest()
    this.setStatus("地図の中心地点でガイドを準備しています…")
    this.requestGuide(coords)
  }

  async requestGuide(coords) {
    this.setStatus("ガイドを準備しています…")
    const abortController = new AbortController()
    const timeoutId = this.developmentValue ? null : window.setTimeout(() => abortController.abort(), 30_000)

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

      this.guideText = payload.speech_text || payload.guide
      this.guideTarget.textContent = payload.guide
      this.guideTarget.hidden = false
      this.setStatus(payload.location ? `${payload.location}付近のガイドです。` : "ガイドを表示しました。")
      this.speakGuide()
    } catch (error) {
      const message = error.name === "AbortError" ? "ガイドの準備に時間がかかっています。もう一度お試しください。" : error.message
      this.showError(message || "通信に失敗しました。")
    } finally {
      if (timeoutId) window.clearTimeout(timeoutId)
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

  async updateMap(coords, { markerTitle = "現在地" } = {}) {
    if (!this.googleMapsApiKeyValue) {
      this.mapNoticeTarget.hidden = false
      this.mapNoticeTarget.textContent = "地図を表示するには、GOOGLE_MAPS_API_KEY を設定してください。"
      return
    }

    try {
      await this.loadGoogleMaps()
      const center = { lat: coords.latitude, lng: coords.longitude }

      if (!this.map) {
        this.map = new window.google.maps.Map(this.mapTarget, {
          center,
          zoom: 16,
          mapTypeControl: false,
          streetViewControl: false
        })
        this.currentLocationMarker = new window.google.maps.Marker({
          map: this.map,
          position: center,
          title: markerTitle
        })
      } else {
        this.map.setCenter(center)
        this.currentLocationMarker.setPosition(center)
        this.currentLocationMarker.setTitle(markerTitle)
      }

      this.mapNoticeTarget.hidden = true
      if (this.hasMapSimulationButtonTarget) this.mapSimulationButtonTarget.hidden = false
    } catch (_) {
      this.mapNoticeTarget.hidden = false
      this.mapNoticeTarget.textContent = "地図を読み込めませんでした。Google Maps APIキーの設定を確認してください。"
    }
  }

  loadGoogleMaps() {
    if (window.google?.maps?.Map) return Promise.resolve()
    if (this.googleMapsLoadingPromise) return this.googleMapsLoadingPromise

    this.googleMapsLoadingPromise = new Promise((resolve, reject) => {
      const callbackName = "aiDriveGuideGoogleMapsReady"
      window[callbackName] = () => {
        delete window[callbackName]
        resolve()
      }

      const script = document.createElement("script")
      const params = new URLSearchParams({
        key: this.googleMapsApiKeyValue,
        loading: "async",
        callback: callbackName,
        v: "weekly",
        language: "ja",
        region: "JP",
        auth_referrer_policy: "origin"
      })
      script.src = `https://maps.googleapis.com/maps/api/js?${params}`
      script.async = true
      script.onerror = () => {
        delete window[callbackName]
        reject(new Error("Google Maps could not load"))
      }
      document.head.appendChild(script)
    })

    return this.googleMapsLoadingPromise
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
    if (this.hasMapSimulationButtonTarget) this.mapSimulationButtonTarget.disabled = true
    this.retrySpeechButtonTarget.hidden = true
  }

  finishRequest() {
    this.isRequesting = false
    this.startButtonTarget.disabled = false
    if (this.hasSimulationButtonTarget) this.simulationButtonTarget.disabled = false
    if (this.hasMapSimulationButtonTarget) this.mapSimulationButtonTarget.disabled = false
  }
}
