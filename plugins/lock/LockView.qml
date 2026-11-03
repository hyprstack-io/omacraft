import QtQuick
import qs.Commons
import qs.Commons as Commons
import "LockDefaults.js" as Defaults

// The same surface as Omarchy's LockView, for the same Service, with the drawing
// handed to LockScene. Only shell things live here: the theme and the translations.
Item {
  id: root

  property var settings: Defaults.clean({})
  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property string hostName: ""
  property string userName: ""
  property bool fingerprintConfigured: false
  property bool fingerprintUnavailable: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool leaving: false

  // A video wallpaper shows its still poster: nothing plays behind the lock.
  readonly property bool video: Util.isVideoPath(root.backgroundPath)

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() { scene.forcePasswordFocus() }
  function clearPassword() { scene.clearPassword() }

  LockScene {
    id: scene
    anchors.fill: parent
    settings: root.settings
    theme: ({
      background: String(Commons.Color.background),
      foreground: String(Commons.Color.lock.text),
      accent: String(Commons.Color.lock.borderActive),
      accent2: String(Commons.Color.lock.borderActive),
      urgent: String(Commons.Color.lock.textError)
    })
    backgroundFile: root.video ? root.videoPosterPath : root.backgroundPath
    backgroundVersion: root.backgroundVersion
    userName: root.userName
    hostName: root.hostName
    defaultPlaceholder: Commons.I18n.t("lock.enterPassword")
    checkingText: Commons.I18n.t("lock.checking")
    fingerprintNotice: Commons.I18n.t("lock.fingerprintUnavailable")
    fingerprintConfigured: root.fingerprintConfigured
    fingerprintUnavailable: root.fingerprintUnavailable
    authenticating: root.authenticatingPassword
    failureMessage: root.failureMessage
    failedAttempts: root.failedAttempts
    inputEnabled: root.inputEnabled
    loadBackground: root.loadBackground
    passwordText: root.passwordText
    leaving: root.leaving
    onSubmitPassword: function(password) { root.submitPassword(password) }
    onPasswordTextEdited: function(password) { root.passwordTextEdited(password) }
    onClearFailureRequested: root.clearFailureRequested()
    onWakeRequested: root.wakeRequested()
  }
}
