require 'rake'
require 'rails/info'

module Redmine
  class About
    include Redmine::I18n
    
    class << self
      def info(options = [])
        print_environment_info(options)
      end
      
      def to_s()
        print_environment_info
      end
      
      def print(header, properties, column_width)
        ["\n", header, '-' * header.length, *properties.map do |property|
          "%-#{column_width}s   %s" % property
        end] * "\n"
      end
      
      def info_title
        { 'checklist' => 'Checklist',
          'rails' => 'Rails Info',
          'plugins' => 'Installed Plugins',
          'gems' => 'Installed Ruby Gems'
        }
      end
      
      def print_environment_info(options = [])
        options = (%w(checklist rails plugins) + options.collect(&:to_s)).uniq
        
        output =  "About your Redmine's environment\n"
        output << "================================"
        
        environment = self.environment(options).inject({}) do |result, (name, info)|
          result[name] = info.collect do |label, value|
            label = label.is_a?(Symbol) ? l(label) : label
            value = (value ? l(:general_text_Yes) : l(:general_text_No)) if (!!value == value) # value is a boolean
            [label, value]
          end
          result
        end

        # get overall width of label column
        column_width = environment.inject(0){|width, (type, data)| [width, data.collect {|label, value| label.length }.max].max}
        
        output += options.collect do |option|
          title = info_title[option] || option.to_s.humnize
          print(title, environment.delete(option), column_width)
        end.join
        output
      end
  
      def environment(options)
        options.inject({}) do |result, info|
          result[info] = send("environment_#{info}")
          result
        end
      end
    
      def environment_checklist
        [
          [:text_default_administrator_account_changed, !!User.find(:first, :conditions => ["login=? and hashed_password=?", 'admin', User.hash_password('admin')]).nil?],
          [:text_file_repository_writable, File.writable?(Attachment.storage_path)],
          [:text_plugin_assets_writable, File.writable?(Engines.public_directory)],
          [:text_rmagick_available, Object.const_defined?(:Magick)]
        ]
      end
    
      def environment_plugins
        Redmine::Plugin.all.collect {|plugin| [plugin.name, plugin.version] } || []
      end
    
      def environment_rails
        app_servers = {
          'Mongrel' => {:name => 'Mongrel', :version => Proc.new{Mongrel::Const::MONGREL_VERSION}},
          'Thin' => {:name => 'Thin', :version => Proc.new{Thin::VERSION::STRING}},
          'Unicorn' => {:name => 'Unicorn', :version => Proc.new{Unicorn::Const::UNICORN_VERSION}},
          'PhusionPassenger' => {:name => 'Phusion Passenger', :version => Proc.new{PhusionPassenger::VERSION_STRING}},
          'RailsFCGIHandler' => {:name => 'FastCGI'}
          # TOOD: find a way to test for CGI
        }
        app_server = (Object.constants & app_servers.keys).collect do |server|
          name = app_servers[server][:name].underscore.humanize
          version = app_servers[server][:version].call if app_servers[server][:version]
          [name, version].compact.join(" ")
        end.join(", ")
        app_server = l(:label_unknown) unless app_server.present?

        # Find database connection encoding
        encoding = case ActiveRecord::Base.connection.adapter_name
        when 'Mysql'
          ActiveRecord::Base.connection.show_variable('character_set%')
        when 'PostgreSQL'
          ActiveRecord::Base.connection.encoding
        when 'SQLite'
          # works like ActiveRecord::ConnectionAdapters::SQLite3Adapter.encoding
          # of the Rails3 Sqlite3 adapter
          if ActiveRecord::Base.connection.respond_to?(:encoding)
            ActiveRecord::Base.connection.encoding[0]['encoding']
          else
            result = ActiveRecord::Base.connection.select_all("PRAGMA 'encoding'")
            result.present? ? result.first['encoding'] : nil
          end
        end || l(:label_unknown)

        result = Rails::Info.properties.dup
        result.insert(3, ['Rake version', RAKEVERSION])
        result.insert(11, [:text_log_file, Rails.configuration.log_path])
        result.insert(13, [:text_database_encoding, encoding])

        result += [
          [:text_app_server, app_server],
          [:text_redmine_username, Etc.getlogin]
        ]
      end
    
      def environment_gems
        gems = Rails::VendorGemSourceIndex.new(Gem.source_index).installed_source_index
        gems = gems.inject(Hash.new([])) do |result, (k, gem)|
          result[gem.name] += [gem.version]
          result
        end
      
        gems.sort_by{|name, versions| name.downcase}.collect do |name, versions|
          [name, versions.sort.join(", ")]
        end
      end
    end
  end
end
