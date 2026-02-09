# Homebrew formula for bopca
# Run LLM agents in lightweight macOS VMs

class Bopca < Formula
  desc "Run LLM agents in lightweight macOS VMs"
  homepage "https://github.com/cboone/bopca"
  version "0.6.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/cboone/bopca/releases/download/v#{version}/bopca-darwin-arm64.tar.gz"
      sha256 "4f657724f5870d90908e42577a21c33d7617e2888a9611939bd2295274ed5f7b"

      def install
        bin.install "bopca"
        install_data_files
      end
    end
  end

  # Data files (Containerfile, config) needed at runtime
  resource "data" do
    url "https://github.com/cboone/bopca/archive/refs/tags/v#{version}.tar.gz"
    sha256 "64e036739a850c354ebf29935d57615a9ac2aed773c6b26245be83da4e124fc3"
  end

  # For building from source (used by `brew install --build-from-source`)
  head "https://github.com/cboone/bopca.git", branch: "main"

  depends_on :macos
  depends_on arch: :arm64
  depends_on "container"
  depends_on "go" => :build

  def install_data_files
    # Extract and install data files from the source archive
    resource("data").stage do
      (share/"bopca").install "Containerfile"
      (share/"bopca/config").install Dir["config/*"]
      (share/"bopca").install "config/bopca.example.yaml"
    end

    # Generate shell completions
    generate_completions_from_executable(bin/"bopca", "completion")

    # Generate and install man pages
    mkdir_p "man/man1"
    system bin/"bopca", "man", "man/man1"
    man1.install Dir["man/man1/*"]
  end

  def install
    if build.head?
      # Build from source for head installs
      ldflags = %W[
        -s -w
        -X main.version=HEAD
        -X main.commit=#{`git rev-parse --short HEAD 2>/dev/null`.strip}
        -X main.date=#{Time.now.utc.iso8601}
      ]
      system "go", "build", *std_go_args(ldflags:)

      # Install data files from source
      (share/"bopca").install "Containerfile"
      (share/"bopca/config").install Dir["config/*"]
      (share/"bopca").install "config/bopca.example.yaml"

      # Generate completions
      generate_completions_from_executable(bin/"bopca", "completion")

      # Generate and install man pages
      mkdir_p "man/man1"
      system bin/"bopca", "man", "man/man1"
      man1.install Dir["man/man1/*"]
    end
    # Binary installs are handled by platform-specific blocks above
  end

  def caveats
    <<~EOS
      Optional: Set up DNS for container hostnames:
        sudo container system dns create test
        container system property set dns.domain test

      Configuration file locations:
        Project: .bopca.yaml or .bopca.yml
        User:    $XDG_CONFIG_HOME/bopca/bopca.yaml or bopca.yml (default: ~/.config/bopca/bopca.yaml or bopca.yml)

      Example config: #{share}/bopca/bopca.example.yaml
    EOS
  end

  test do
    assert_match "bopca", shell_output("#{bin}/bopca --help")
    assert_match version.to_s, shell_output("#{bin}/bopca version") unless build.head?
  end
end
