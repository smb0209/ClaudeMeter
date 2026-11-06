cask "claudemeter" do
  version "1.4.1"
  sha256 "5b80ed670b0e2d98f00909778c55918ca214c466278ef1c1b49627339fb0a1ca"

  url "https://github.com/smb0209/ClaudeMeter/releases/download/v#{version}/ClaudeMeter-#{version}.zip"
  name "ClaudeMeter"
  desc "Menu bar app for monitoring Claude.ai plan usage"
  homepage "https://github.com/smb0209/ClaudeMeter"

  depends_on macos: :sonoma

  app "ClaudeMeter.app"

  # Ad-hoc signed and not notarized (see scripts/release.sh), so Gatekeeper would block it.
  # No declarative install step clears quarantine, hence the flight block.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/ClaudeMeter.app"]
  end

  zap trash: [
    "~/.claudemeter",
    "~/Library/Application Support/com.claudemeter",
    "~/Library/Containers/com.eddmann.ClaudeMeter",
    "~/Library/Preferences/com.eddmann.ClaudeMeter.plist",
  ]
end
