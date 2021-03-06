# frozen_string_literal: true

require_relative "boot"

require "rails/all"
require "cldr"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Require the application specific engines for the custom verifications.
require File.expand_path("../lib/engines", __dir__)

module DecidimHelsinki
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Configure an application wide address suffix to pass to the geocoder.
    # This is to make sure that the addresses are not incorrectly mapped outside
    # of the wanted area.
    config.address_suffix = "Helsinki, Finland"

    # Sending address for mails
    config.mailer_sender = "no-reply@omastadi.hel.fi"

    # Tracking
    config.snoobi_account = nil

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Add the override translations to the load path
    config.i18n.load_path += Dir[
      Rails.root.join("config", "locales", "crowdin-master/*.yml").to_s,
      Rails.root.join("config", "locales", "overrides/*.yml").to_s,
    ]

    # String identifier, this defines the main mode of Decidim
    # See README.md for more explation on this.
    #
    # Available throughout code as: Rails.application.config.use_mode
    # Allowed values are:
    #   "private" : string = Private mode (force logging in)
    #   "normal" : string = Normal mode without modifications
    config.use_mode = "normal"

    # Wrapper class can be used to customize the coloring of the platform per
    # environment. This is used mainly for the Ideapaahtimo/KuVa instance.
    config.wrapper_class = "wrapper-default"

    # Color profile that changes the logo color for header and footer
    config.color_profile = "black"

    # The feedback email in the footer of the site
    config.feedback_email = "omastadi@hel.fi"

    # This defines an email address for automatically generated user accounts,
    # e.g. through the Suomi.fi or MPASSid authentications.
    config.auto_email_domain = "omastadi.hel.fi"

    config.suomifi_enabled = false
    config.mpassid_enabled = false

    # Passes a block of code to do after initialization.
    config.after_initialize do
      # Override the main menu
      Decidim::MenuRegistry.create(:menu)
      Decidim.menu :menu do |menu|
        menu.item I18n.t("menu.home", scope: "decidim"),
                  decidim.root_path,
                  position: 1,
                  active: :exact

        menu.item I18n.t("menu.processes", scope: "decidim"),
                  decidim_participatory_processes.participatory_processes_path,
                  position: 2,
                  active: :inclusive

        menu.item I18n.t("menu.more_information", scope: "decidim"),
                  decidim.pages_path,
                  position: 3,
                  active: :inclusive
      end
    end

    initializer "user_authentication" do |app|
      Decidim::User.send(:include, UserAuthentication)

      # The following hook is for the development environment and it is needed
      # to load the correct omniauth configurations to the Decidim::User model
      # BEFORE the routes are reloaded in Decidim::Core::Engine. Without this,
      # the extra omniauth authentication methods are lost during application
      # reloads as the Decidim::User class is reloaded during which the omniauth
      # configurations are overridden by the core class. After the override, the
      # routes are reloaded (before call to to_prepare) which causes the extra
      # configured methods to be lost.
      #
      # The load order is:
      # - Models, including Decidim::Core::Engine models (sets the omniauth back
      #   to Decidim defaults)
      # - ActionDispatch::Reloader - after_class_unload hook (below)
      # - Routes, including Decidim::Core::Engine routes (reloads the routes
      #   using the omniauth providers set by Decidim::Core)
      # - to_prepare hook (which would be the optimal place for this but too
      #   late in the load process)
      #
      # In case you are planning to change this, make sure that the following
      # works:
      # - Start the application with Tunnistamo omniauth method configured
      # - Load the login page and see that Tunnistamo is configured
      # - Make a change to any file under the `app` folder
      # - Reload the login page and see that Tunnistamo is configured
      #
      # This could be also fixed in the Decidim core by making the omniauth
      # providers configurable through the application configs. See:
      # https://github.com/decidim/decidim/blob/a40656/decidim-core/app/models/decidim/user.rb#L17
      #
      # NOTE: This problem only occurs when the models and routes are reloaded,
      #       i.e. in development environment.
      app.reloader.after_class_unload do
        Decidim::User.send(:include, UserAuthentication)
      end
    end

    initializer "devise_overrides" do
      # Devise controller overrides to add some extra functionality into them.
      # Currently this is only for debugging purposes.
      ActiveSupport.on_load(:action_controller) do
        include DeviseOverrides
      end
    end

    # See:
    # https://guides.rubyonrails.org/configuring.html#initialization-events
    #
    # Run before every request in development.
    config.to_prepare do
      # Helper extensions
      Decidim::Comments::CommentsHelper.send(
        :include,
        CommentsHelperExtensions
      )

      # Parser extensions
      Decidim::ContentParsers::ProposalParser.send(
        :include,
        Helsinki::ProposalParserExtensions
      )

      # View extensions
      ActionView::Base.send :include, Decidim::MapHelper
      ActionView::Base.send :include, Decidim::WidgetUrlsHelper

      # Controller concern extensions
      # See: https://github.com/decidim/decidim/pull/5313
      Decidim::NeedsTosAccepted.send(:include, TosRedirectFix)

      # Extra helpers
      Decidim::Assemblies::ContentBlocks::HighlightedAssembliesCell.send(
        :include,
        Decidim::ApplicationHelper
      )
      Decidim::Assemblies::ContentBlocks::HighlightedAssembliesCell.send(
        :include,
        Decidim::SanitizeHelper
      )
    end
  end
end
