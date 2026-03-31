class Eyes < Formula
  desc "Lightweight break reminder app — follow the 20-20-20 rule"
  homepage "https://github.com/lightsaway/eyes"
  version "0.1.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/lightsaway/eyes/releases/download/v#{version}/eyes-macos-arm64.tar.gz"
      sha256 "PLACEHOLDER_ARM64_SHA256"
    else
      url "https://github.com/lightsaway/eyes/releases/download/v#{version}/eyes-macos-x86_64.tar.gz"
      sha256 "PLACEHOLDER_X86_64_SHA256"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/lightsaway/eyes/releases/download/v#{version}/eyes-linux-aarch64.tar.gz"
      sha256 "PLACEHOLDER_LINUX_AARCH64_SHA256"
    else
      url "https://github.com/lightsaway/eyes/releases/download/v#{version}/eyes-linux-x86_64.tar.gz"
      sha256 "PLACEHOLDER_LINUX_X86_64_SHA256"
    end
  end

  on_linux do
    depends_on "gtk+3"
    depends_on "libappindicator"
    depends_on "libnotify"
    depends_on "libcanberra"
  end

  def install
    bin.install "eyes"
  end

  def caveats
    on_macos do
      <<~EOS
        To start Eyes on login, run:
          eyes &

        Or use the "Start at Login" option from the menu bar icon.
      EOS
    end
  end

  test do
    assert_predicate bin/"eyes", :executable?
  end
end
