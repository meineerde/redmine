require 'rake'
require 'rails/info'

module Redmine
  class About
    include Redmine::I18n
    
    class << self
      def to_s
        print_plugin_info
      end
      
      def print(header, properties, column_width)
        ["\n", header, '-' * header.length, *properties.map do |property|
          "%-#{column_width}s   %s" % property
        end] * "\n"
      end
      
      def print_plugin_info
        environment = self.environment

        output =  "About your Redmine's environment\n"
        output << "================================"

        checklist = environment[:checklist].collect {|label, value| [l(label), value ? "Yes" : "No"]}
        info = environment[:rails].collect {|label, value| [(label.is_a?(Symbol) ? l(label) : label), value]}
        plugins = environment[:plugins].collect {|plugin| [plugin.name, plugin.version] } || nil

        # get overall width of label column
        column_width = [
          checklist.collect {|label, value| label.length }.max,
          info.collect {|label, value| label.length }.max,
          plugins.collect {|label, value| label.length }.max || 0
        ].max

        output += print("Checklist", checklist, column_width)
        output += print("Rails info", info, column_width)
        output += print("Plugins", plugins, column_width) if plugins.present?

        output
      end
  
      def environment
        environment = {}
        environment[:checklist] = [
          [:text_default_administrator_account_changed, User.find(:first, :conditions => ["login=? and hashed_password=?", 'admin', User.hash_password('admin')]).nil?],
          [:text_file_repository_writable, File.writable?(Attachment.storage_path)],
          [:text_plugin_assets_writable, File.writable?(Engines.public_directory)],
          [:text_rmagick_available, Object.const_defined?(:Magick)]
        ]
    
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

        environment[:rails] = Rails::Info.properties.dup
        environment[:rails].tap do |info|
          info.insert(3, ['Rake version', RAKEVERSION])
          info.insert(11, [:text_log_file, Rails.configuration.log_path])
          info.insert(13, [:text_database_encoding, encoding])
        end

        environment[:rails] += [
          [:text_app_server, app_server],
          [:text_redmine_username, Etc.getlogin]
        ]
    
        environment[:plugins] = Redmine::Plugin.all
    
        environment
      end
    end
  end
end
