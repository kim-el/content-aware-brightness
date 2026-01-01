class ContentAwareBrightness < Formula
  desc "Automatically adjust screen brightness based on content"
  homepage "https://github.com/kim-el/content-aware-brightness"
  url "https://github.com/kim-el/content-aware-brightness/archive/refs/tags/v3.0.tar.gz"
  sha256 "REPLACE_WITH_REAL_SHA256_AFTER_TAGGING"
  license "MIT"
  head "https://github.com/kim-el/content-aware-brightness.git", branch: "main"

  depends_on :xcode => ["12.0", :build]

  def install
    # 1. Create App Bundle Structure
    app_bundle = "ContentAwareBrightness.app"
    macos_dir = "#{app_bundle}/Contents/MacOS"
    resources_dir = "#{app_bundle}/Contents/Resources"
    
    mkdir_p macos_dir
    mkdir_p resources_dir
    
    # 2. Compile Swift binary
    system "swiftc", "-O", 
           "-Xlinker", "-F/System/Library/PrivateFrameworks",
           "-Xlinker", "-framework", "-Xlinker", "DisplayServices",
           "-o", "#{macos_dir}/ContentAwareBrightness", "auto-brightness.swift"
    
    # 3. Create Info.plist (Critical for TCC/Permissions)
    File.write "#{app_bundle}/Contents/Info.plist", <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>CFBundleName</key>
          <string>ContentAwareBrightness</string>
          <key>CFBundleExecutable</key>
          <string>ContentAwareBrightness</string>
          <key>CFBundleIdentifier</key>
          <string>com.kim.ContentAwareBrightness</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>LSUIElement</key>
          <true/>
          <key>NSScreenCaptureUsageDescription</key>
          <string>Content-Aware Brightness needs screen access to adjust display brightness.</string>
      </dict>
      </plist>
    EOS

    # 4. Install the App Bundle
    prefix.install app_bundle
    
    # 5. Create a symlink in bin so it can be run from CLI (optional)
    bin.install_symlink "#{prefix}/#{app_bundle}/Contents/MacOS/ContentAwareBrightness" => "content-aware-brightness"
  end

  service do
    run [opt_prefix/"ContentAwareBrightness.app/Contents/MacOS/ContentAwareBrightness"]
    keep_alive true
    run_type :interval
    interval 10
    log_path var/"log/content-aware-brightness.log"
    error_log_path var/"log/content-aware-brightness.error.log"
  end
end
