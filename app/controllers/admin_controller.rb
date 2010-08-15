# redMine - project management software
# Copyright (C) 2006  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'rake'
require 'rails/info'
class AdminController < ApplicationController
  layout 'admin'
  
  before_filter :require_admin

  helper :sort
  include SortHelper	

  def index
    @no_configuration_data = Redmine::DefaultData::Loader::no_data?
  end
	
  def projects
    @status = params[:status] ? params[:status].to_i : 1
    c = ARCondition.new(@status == 0 ? "status <> 0" : ["status = ?", @status])
    
    unless params[:name].blank?
      name = "%#{params[:name].strip.downcase}%"
      c << ["LOWER(identifier) LIKE ? OR LOWER(name) LIKE ?", name, name]
    end
    
    @projects = Project.find :all, :order => 'lft',
                                   :conditions => c.conditions

    render :action => "projects", :layout => false if request.xhr?
  end
  
  def plugins
    @plugins = Redmine::Plugin.all
  end
  
  # Loads the default configuration
  # (roles, trackers, statuses, workflow, enumerations)
  def default_configuration
    if request.post?
      begin
        Redmine::DefaultData::Loader::load(params[:lang])
        flash[:notice] = l(:notice_default_data_loaded)
      rescue Exception => e
        flash[:error] = l(:error_can_t_load_default_data, e.message)
      end
    end
    redirect_to :action => 'index'
  end
  
  def test_email
    raise_delivery_errors = ActionMailer::Base.raise_delivery_errors
    # Force ActionMailer to raise delivery errors so we can catch it
    ActionMailer::Base.raise_delivery_errors = true
    begin
      @test = Mailer.deliver_test(User.current)
      flash[:notice] = l(:notice_email_sent, User.current.mail)
    rescue Exception => e
      flash[:error] = l(:notice_email_error, e.message)
    end
    ActionMailer::Base.raise_delivery_errors = raise_delivery_errors
    redirect_to :controller => 'settings', :action => 'edit', :tab => 'notifications'
  end
  
  def info
    @checklist = [
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
    end.join(",")
    app_server = l(:label_unknown) unless app_server.present?
    
    # Find database connection encoding
    encoding = case ActiveRecord::Base.connection.adapter_name
    when 'Mysql'
      ActiveRecord::Base.connection.show_variable('character_set%')
    when 'PostgreSQL'
      ActiveRecord::Base.connection.encoding
    when 'SQLite'
      # copied straight from ActiveRecord::ConnectionAdapters::SQLite3Adapter.encoding
      # of the Rails3 Sqlite3 adapter
      if ActiveRecord::Base.connection.respond_to?(:encoding)
        ActiveRecord::Base.connection.encoding[0]['encoding']
      else
        result = ActiveRecord::Base.connection.select_all("PRAGMA 'encoding'")
        result.present? ? result.first['encoding'] : nil
      end
    end || l(:label_unknown)
    
    @infolist = Rails::Info.properties.dup
    @infolist.insert(3, ['Rake version', RAKEVERSION])
    @infolist.insert(11, [:text_log_file, Rails.configuration.log_path])
    @infolist.insert(13, [:text_database_encoding, encoding])
    
    @infolist += [
      [:text_app_server, app_server],
      [:text_redmine_username, Etc.getlogin]
    ]
    
    @pluginlist = Redmine::Plugin.all
  end  
end
