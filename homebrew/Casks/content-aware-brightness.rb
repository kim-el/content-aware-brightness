  version "3.0"
  sha256 :no_check 
  # TODO: 1. Run 'shasum -a 256 ContentAwareBrightness_v3.0.zip'
  #       2. Replace ':no_check' with the actual hash string, e.g., "d3b07384d..."

  # Production URL (Uncomment this for public release)
  # url "https://github.com/kim-el/content-aware-brightness/releases/download/v#{version}/ContentAwareBrightness_v#{version}.zip"
  
  # Local Testing URL (Comment this out before publishing)
  url "file://#{Dir.pwd}/build/ContentAwareBrightness_v3.0.zip"

  name "Content Aware Brightness"
  desc "Auto-adjust screen brightness based on active content (Luma)"
  homepage "https://github.com/kim-el/content-aware-brightness"
  desc "Auto-adjust screen brightness based on active content (Luma)"
  homepage "https://github.com/kim-el/content-aware-brightness"

  app "ContentAwareBrightness.app"

  uninstall quit: "com.kim.ContentAwareBrightness"

  caveats <<~EOS
    This app requires Screen Recording permission to function.
    Grant it in System Settings -> Privacy & Security -> Screen Recording.
  EOS
end
