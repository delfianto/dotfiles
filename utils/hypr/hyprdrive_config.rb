# hyprdrive_config.rb: Hold the hyprdrive yaml config as Ruby objects.
# frozen_string_literal: true

require "yaml"

# Shared module for method_missing logic to access keys within custom sections.
# This allows calling `apps.foo` as a shortcut for `apps.custom_actions[:foo]`.
module CustomSectionAccessor
  def method_missing(method_name, *arguments, &block)
    # Determine which attribute holds the custom data for this class instance
    custom_attr_sym = case self
                      when HyprdriveConfig::AppsConfig, HyprdriveConfig::ActionsConfig
                        :custom_actions
                      when HyprdriveConfig::ComponentsConfig
                        :custom_components
                      else
                        # This case should ideally not be reached if the module is included correctly.
                        return super # Fallback to default behavior if no custom section is applicable
                      end

    # Proceed only if a relevant custom attribute symbol is identified
    # and the instance actually responds to (has) that attribute.
    if custom_attr_sym && respond_to?(custom_attr_sym, false)
      custom_data_hash = public_send(custom_attr_sym) # Retrieve the custom hash (e.g., @custom_actions)

      if custom_data_hash.is_a?(Hash)
        # Try symbol key first, then string key, to access the value within the custom hash
        return custom_data_hash[method_name] if custom_data_hash.key?(method_name)

        s_method_name = method_name.to_s
        return custom_data_hash[s_method_name] if custom_data_hash.key?(s_method_name)
      end
    end
    super # If method not found in custom section, or no custom section, call original method_missing
  end

  def respond_to_missing?(method_name, include_private = false)
    custom_attr_sym = case self
                      when HyprdriveConfig::AppsConfig, HyprdriveConfig::ActionsConfig
                        :custom_actions
                      when HyprdriveConfig::ComponentsConfig
                        :custom_components
                      else
                        return super # Fallback if not one of the designated classes
                      end

    if custom_attr_sym && respond_to?(custom_attr_sym, false)
      custom_data_hash = public_send(custom_attr_sym)
      if custom_data_hash.is_a?(Hash)
        # Check if the key exists as a symbol or string in the custom hash
        # The custom initialize methods already convert keys to symbols, so checking method_name.to_s might be redundant
        # but kept for robustness if data could be manipulated post-initialization.
        return true if custom_data_hash.key?(method_name) || custom_data_hash.key?(method_name.to_s)
      end
    end
    super # Default respond_to_missing? behavior
  end
end

module HyprdriveConfig
  # Apps configuration
  AppsConfig = Data.define(
    :archive, :browser, :calculator, :calendar, :color_picker, :editor,
    :emoji_picker, :file_manager, :music, :package, :screenshot,
    :sysmon_cli, :sysmon_gui, :terminal, :video, :volume,
    :custom_actions # This will hold the hash, e.g., {foo: "bar_app"}
  ) do
    include CustomSectionAccessor # Enable dynamic access like `apps.foo`

    # Custom initializer to ensure custom_actions is a Hash with symbolized keys.
    # All other attributes are passed as keyword arguments.
    def initialize(custom_actions: {}, **attributes)
      processed_custom_actions = (custom_actions || {}).transform_keys(&:to_sym) #
      super(**attributes, custom_actions: processed_custom_actions)
    end
  end

  # Actions configuration
  ActionsConfig = Data.define(
    :lock, :sleep,
    :volume_up, :volume_down,
    :brightness_up, :brightness_down,
    :custom_actions
  ) do
    include CustomSectionAccessor

    def initialize(custom_actions: {}, **attributes)
      processed_custom_actions = (custom_actions || {}).transform_keys(&:to_sym) #
      super(**attributes, custom_actions: processed_custom_actions)
    end
  end

  # Components configuration
  ComponentsConfig = Data.define(
    :dock, :app_launcher,
    :status_bar, :xdg_portal,
    :custom_components
  ) do
    include CustomSectionAccessor

    def initialize(xdg_portal: [], custom_components: {}, **attributes)
      processed_xdg_portal = Array(xdg_portal) # Ensure xdg_portal is an array
      processed_custom_components = (custom_components || {}).transform_keys(&:to_sym) #
      super(**attributes, xdg_portal: processed_xdg_portal, custom_components: processed_custom_components)
    end
  end

  # Internal class for the 'hyprland' key structure
  HyprlandData = Data.define(:apps, :actions, :components)

  # Top-level config object
  RootConfig = Data.define(:hyprland)

  # Factory method to parse YAML and create the structured objects
  def self.load_from_yaml(yaml_string)
    raw_data = YAML.safe_load(yaml_string, symbolize_names: true)
    return nil unless raw_data && raw_data[:hyprland]

    hyprland_data_map = raw_data[:hyprland]
    
    apps_data = hyprland_data_map[:apps] || {}
    apps_config = AppsConfig.new(**apps_data.slice(*AppsConfig.members))

    actions_data = hyprland_data_map[:actions] || {}
    actions_config = ActionsConfig.new(**actions_data.slice(*ActionsConfig.members))

    components_data = hyprland_data_map[:components] || {}
    components_config = ComponentsConfig.new(**components_data.slice(*ComponentsConfig.members))

    hyprland_obj = HyprlandData.new(
      apps: apps_config,
      actions: actions_config,
      components: components_config
    )

    RootConfig.new(hyprland: hyprland_obj)
  end
end
