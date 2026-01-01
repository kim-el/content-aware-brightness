class ContentAwareBrightness < Formula
  desc "Automatically adjust screen brightness based on content"
  homepage "https://github.com/kim-el/content-aware-brightness"
  url "https://github.com/kim-el/content-aware-brightness/archive/refs/tags/v3.0.tar.gz"
  sha256 "REPLACE_WITH_REAL_SHA256_AFTER_TAGGING"
  license "MIT"
  head "https://github.com/kim-el/content-aware-brightness.git", branch: "main"

  depends_on :xcode => ["12.0", :build]

  def install
    system "swiftc", "-O", 
           "-Xlinker", "-F/System/Library/PrivateFrameworks",
           "-Xlinker", "-framework", "-Xlinker", "DisplayServices",
           "-o", "content-aware-brightness", "auto-brightness.swift"
    
    bin.install "content-aware-brightness"
  end

  service do
    run [opt_bin/"content-aware-brightness"]
    keep_alive true
    run_type :interval
    interval 10
    log_path var/"log/content-aware-brightness.log"
    error_log_path var/"log/content-aware-brightness.error.log"
  end
end
