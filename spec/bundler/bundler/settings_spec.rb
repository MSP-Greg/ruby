# frozen_string_literal: true

require "bundler/settings"

RSpec.describe Bundler::Settings do
  subject(:settings) { described_class.new(bundled_app) }

  describe "#set_local" do
    context "root is nil" do
      subject(:settings) { described_class.new(nil) }

      before do
        allow(Pathname).to receive(:new).and_call_original
        allow(Pathname).to receive(:new).with(".bundle").and_return home(".bundle")
      end

      it "works" do
        subject.set_local("foo", "bar")

        expect(subject["foo"]).to eq("bar")
      end
    end
  end

  describe "load_config" do
    let(:hash) do
      {
        "build.thrift" => "--with-cppflags=-D_FORTIFY_SOURCE=0",
        "build.libv8" => "--with-system-v8",
        "build.therubyracer" => "--with-v8-dir",
        "build.pg" => "--with-pg-config=/usr/local/Cellar/postgresql92/9.2.8_1/bin/pg_config",
        "gem.coc" => "false",
        "gem.mit" => "false",
        "gem.test" => "minitest",
        "thingy" => <<-EOS.tr("\n", " "),
--asdf --fdsa --ty=oh man i hope this doesn't break bundler because
that would suck --ehhh=oh geez it looks like i might have broken bundler somehow
--very-important-option=DontDeleteRoo
--very-important-option=DontDeleteRoo
--very-important-option=DontDeleteRoo
--very-important-option=DontDeleteRoo
        EOS
        "xyz" => "zyx",
      }
    end

    before do
      hash.each do |key, value|
        settings.set_local key, value
      end
    end

    it "can load the config" do
      loaded = settings.send(:load_config, bundled_app("config"))
      expected = Hash[hash.map do |k, v|
        [settings.send(:key_for, k), v.to_s]
      end]
      expect(loaded).to eq(expected)
    end

    context "when BUNDLE_IGNORE_CONFIG is set" do
      before { ENV["BUNDLE_IGNORE_CONFIG"] = "TRUE" }

      it "ignores the config" do
        loaded = settings.send(:load_config, bundled_app("config"))
        expect(loaded).to eq({})
      end
    end
  end

  describe "#global_config_file" do
    context "when $HOME is not accessible" do
      it "does not raise" do
        expect(Bundler.rubygems).to receive(:user_home).twice.and_return(nil)

        expect(subject.send(:global_config_file)).to be_nil
      end
    end
  end

  describe "#[]" do
    context "when the local config file is not found" do
      subject(:settings) { described_class.new }

      it "does not raise" do
        expect do
          subject["foo"]
        end.not_to raise_error
      end
    end

    context "when not set" do
      context "when default value present" do
        it "retrieves value" do
          expect(settings[:retry]).to be 3
        end
      end

      it "returns nil" do
        expect(settings[:buttermilk]).to be nil
      end
    end

    context "when is boolean" do
      it "returns a boolean" do
        settings.set_local :frozen, "true"
        expect(settings[:frozen]).to be true
      end
      context "when specific gem is configured" do
        it "returns a boolean" do
          settings.set_local "ignore_messages.foobar", "true"
          expect(settings["ignore_messages.foobar"]).to be true
        end
      end
    end

    context "when is number" do
      it "returns a number" do
        settings.set_local :ssl_verify_mode, "1"
        expect(settings[:ssl_verify_mode]).to be 1
      end
    end

    context "when it's not possible to create the settings directory" do
      it "raises an PermissionError with explanation" do
        settings_dir = settings.send(:local_config_file).dirname
        expect(::Bundler::FileUtils).to receive(:mkdir_p).with(settings_dir).
          and_raise(Errno::EACCES.new(settings_dir.to_s))
        expect { settings.set_local :frozen, "1" }.
          to raise_error(Bundler::PermissionError, /#{settings_dir}/)
      end
    end
  end

  describe "#temporary" do
    it "reset after used" do
      allow(Bundler::SharedHelpers).to receive(:find_gemfile).and_return(bundled_app_gemfile)

      Bundler.settings.set_command_option :no_install, true

      Bundler.settings.temporary(no_install: false) do
        expect(Bundler.settings[:no_install]).to eq false
      end

      expect(Bundler.settings[:no_install]).to eq true

      Bundler.settings.set_command_option :no_install, nil
    end

    it "returns the return value of the block" do
      ret = Bundler.settings.temporary({}) { :ret }
      expect(ret).to eq :ret
    end

    context "when called without a block" do
      it "leaves the setting changed" do
        Bundler.settings.temporary(foo: :random)
        expect(Bundler.settings[:foo]).to eq "random"
      end

      it "returns nil" do
        expect(Bundler.settings.temporary(foo: :bar)).to be_nil
      end
    end
  end

  describe "#set_global" do
    context "when it's not possible to write to create the settings directory" do
      it "raises an PermissionError with explanation" do
        settings_dir = settings.send(:global_config_file).dirname
        expect(::Bundler::FileUtils).to receive(:mkdir_p).with(settings_dir).
          and_raise(Errno::EACCES.new(settings_dir.to_s))
        expect { settings.set_global(:frozen, "1") }.
          to raise_error(Bundler::PermissionError, /#{settings_dir}/)
      end
    end
  end

  describe "#pretty_values_for" do
    it "prints the converted value rather than the raw string" do
      bool_key = described_class::BOOL_KEYS.first
      settings.set_local(bool_key, "false")
      expect(subject.pretty_values_for(bool_key)).to eq [
        "Set for your local app (#{bundled_app("config")}): false",
      ]
    end
  end

  describe "#mirror_for" do
    let(:uri) { Gem::URI("https://rubygems.org/") }

    context "with no configured mirror" do
      it "returns the original URI" do
        expect(settings.mirror_for(uri)).to eq(uri)
      end

      it "converts a string parameter to a URI" do
        expect(settings.mirror_for("https://rubygems.org/")).to eq(uri)
      end
    end

    context "with a configured mirror" do
      let(:mirror_uri) { Gem::URI("https://example-mirror.rubygems.org/") }

      before { settings.set_local "mirror.https://rubygems.org/", mirror_uri.to_s }

      it "returns the mirror URI" do
        expect(settings.mirror_for(uri)).to eq(mirror_uri)
      end

      it "converts a string parameter to a URI" do
        expect(settings.mirror_for("https://rubygems.org/")).to eq(mirror_uri)
      end

      it "normalizes the URI" do
        expect(settings.mirror_for("https://rubygems.org")).to eq(mirror_uri)
      end

      it "is case insensitive" do
        expect(settings.mirror_for("HTTPS://RUBYGEMS.ORG/")).to eq(mirror_uri)
      end

      context "with a file URI" do
        let(:mirror_uri) { Gem::URI("file:/foo/BAR/baz/qUx/") }

        it "returns the mirror URI" do
          expect(settings.mirror_for(uri)).to eq(mirror_uri)
        end

        it "converts a string parameter to a URI" do
          expect(settings.mirror_for("file:/foo/BAR/baz/qUx/")).to eq(mirror_uri)
        end

        it "normalizes the URI" do
          expect(settings.mirror_for("file:/foo/BAR/baz/qUx")).to eq(mirror_uri)
        end
      end
    end
  end

  describe "#credentials_for" do
    let(:uri) { Gem::URI("https://gemserver.example.org/") }
    let(:credentials) { "username:password" }

    context "with no configured credentials" do
      it "returns nil" do
        expect(settings.credentials_for(uri)).to be_nil
      end
    end

    context "with credentials configured by URL" do
      before { settings.set_local "https://gemserver.example.org/", credentials }

      it "returns the configured credentials" do
        expect(settings.credentials_for(uri)).to eq(credentials)
      end
    end

    context "with credentials configured by hostname" do
      before { settings.set_local "gemserver.example.org", credentials }

      it "returns the configured credentials" do
        expect(settings.credentials_for(uri)).to eq(credentials)
      end
    end
  end

  describe "URI normalization" do
    it "normalizes HTTP URIs in credentials configuration" do
      settings.set_local "http://gemserver.example.org", "username:password"
      expect(settings.all).to include("http://gemserver.example.org/")
    end

    it "normalizes HTTPS URIs in credentials configuration" do
      settings.set_local "https://gemserver.example.org", "username:password"
      expect(settings.all).to include("https://gemserver.example.org/")
    end

    it "normalizes HTTP URIs in mirror configuration" do
      settings.set_local "mirror.http://rubygems.org", "http://example-mirror.rubygems.org"
      expect(settings.all).to include("mirror.http://rubygems.org/")
    end

    it "normalizes HTTPS URIs in mirror configuration" do
      settings.set_local "mirror.https://rubygems.org", "http://example-mirror.rubygems.org"
      expect(settings.all).to include("mirror.https://rubygems.org/")
    end

    it "does not normalize other config keys that happen to contain 'http'" do
      settings.set_local "local.httparty", home("httparty")
      expect(settings.all).to include("local.httparty")
    end

    it "does not normalize other config keys that happen to contain 'https'" do
      settings.set_local "local.httpsmarty", home("httpsmarty")
      expect(settings.all).to include("local.httpsmarty")
    end

    it "reads older keys without trailing slashes" do
      settings.set_local "mirror.https://rubygems.org", "http://example-mirror.rubygems.org"
      expect(settings.mirror_for("https://rubygems.org/")).to eq(
        Gem::URI("http://example-mirror.rubygems.org/")
      )
    end

    it "normalizes URIs with a fallback_timeout option" do
      settings.set_local "mirror.https://rubygems.org/.fallback_timeout", "true"
      expect(settings.all).to include("mirror.https://rubygems.org/.fallback_timeout")
    end

    it "normalizes URIs with a fallback_timeout option without a trailing slash" do
      settings.set_local "mirror.https://rubygems.org.fallback_timeout", "true"
      expect(settings.all).to include("mirror.https://rubygems.org/.fallback_timeout")
    end
  end

  describe "BUNDLE_ keys format" do
    let(:settings) { described_class.new(bundled_app(".bundle")) }

    it "converts older keys without double underscore" do
      config("BUNDLE_MY__PERSONAL.MYRACK" => "~/Work/git/myrack")
      expect(settings["my.personal.myrack"]).to eq("~/Work/git/myrack")
    end

    it "converts older keys without trailing slashes and double underscore" do
      config("BUNDLE_MIRROR__HTTPS://RUBYGEMS.ORG" => "http://example-mirror.rubygems.org")
      expect(settings["mirror.https://rubygems.org/"]).to eq("http://example-mirror.rubygems.org")
    end

    it "ignores commented out keys" do
      create_file bundled_app(".bundle/config"), <<~C
        # BUNDLE_MY-PERSONAL-SERVER__ORG: my-personal-server.org
      C

      expect(Bundler.ui).not_to receive(:warn)
      expect(settings.all).to eq(simulated_version ? ["simulate_version"] : [])
    end

    it "converts older keys with dashes" do
      config("BUNDLE_MY-PERSONAL-SERVER__ORG" => "my-personal-server.org")
      expect(Bundler.ui).to receive(:warn).with(
        "Your #{bundled_app(".bundle/config")} config includes `BUNDLE_MY-PERSONAL-SERVER__ORG`, which contains the dash character (`-`).\n" \
        "This is deprecated, because configuration through `ENV` should be possible, but `ENV` keys cannot include dashes.\n" \
        "Please edit #{bundled_app(".bundle/config")} and replace any dashes in configuration keys with a triple underscore (`___`)."
      )
      expect(settings["my-personal-server.org"]).to eq("my-personal-server.org")
    end

    it "reads newer keys format properly" do
      config("BUNDLE_MIRROR__HTTPS://RUBYGEMS__ORG/" => "http://example-mirror.rubygems.org")
      expect(settings["mirror.https://rubygems.org/"]).to eq("http://example-mirror.rubygems.org")
    end
  end
end
