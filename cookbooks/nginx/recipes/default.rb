recipe = self
stack = node.engineyard.environment['stack_name']
mongrel_unicorn = /(nginx_unicorn|nginx_mongrel)/
php_fpm = /nginx_fpm/

Chef::Log.debug "Nginx action: #{node['nginx'][:action]}"
nginx_version = node['nginx']['version']
Chef::Log.info "Nginx version: #{nginx_version}"

include_recipe 'nginx::install'

=begin TODOv6
tlsv12_available  = node.openssl.version =~ /1\.0\.1/

execute "reload-haproxy" do
  command 'if /etc/init.d/haproxy status ; then /etc/init.d/haproxy reload; else /etc/init.d/haproxy restart; fi'
  action :nothing
end
=end

Chef::Log.info "instance role: #{node['dna']['instance_role']}"
service "nginx" do
  action :nothing
  supports :restart => true, :status => true, :reload => true
  only_if { ['solo','app', 'app_master'].include?(node['dna']['instance_role']) }
end


=begin TODOv6
# This should become a service resource, once we have it for gentoo
runlevel 'nginx' do
  action :add
end


managed_template "/etc/conf.d/nginx" do
  source "conf.d/nginx.erb"
  variables({
    :nofile => 16384
  })
  notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
end

file "/data/nginx/stack.conf" do
  action :create_if_missing
  owner node['owner_name']
  group node['owner_name']
  mode 0644
end
=end

behind_proxy = true
managed_template "/data/nginx/nginx.conf" do
  owner node['owner_name']
  group node['owner_name']
  mode 0644
  source "nginx-plusplus.conf.erb"
  variables(
    lazy {
      {
        :user => node['owner_name'],
        :pool_size => recipe.get_pool_size,
        :behind_proxy => behind_proxy
      }
    }
  )
  notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
end

file "/data/nginx/http-custom.conf" do
  action :create_if_missing
  owner node['owner_name']
  group node['owner_name']
  mode 0644
end

directory "/data/nginx/ssl" do
  owner node['owner_name']
  group node['owner_name']
  mode 0775
end

managed_template "/data/nginx/common/proxy.conf" do
  owner node['owner_name']
  group node['owner_name']
  mode 0644
  source "common.proxy.conf.erb"
  notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
end

managed_template "/data/nginx/common/servers.conf" do
  owner node['owner_name']
  group node['owner_name']
  mode 0644
  source "common.servers.conf.erb"
  notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
end

file "/data/nginx/servers/default.conf" do
  owner node['owner_name']
  group node['owner_name']
  mode 0644
  notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
end

(node['dna']['removed_applications']||[]).each do |app|
  execute "remove-old-vhosts-for-#{app}" do
    command "rm -rf /data/nginx/servers/#{app}*"
    notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
  end
end

node.engineyard.apps.each_with_index do |app, index|

  dhparam_available = app.metadata('dh_key',nil)

  if dhparam_available
    managed_template "/data/nginx/ssl/dhparam.#{app.name}.pem" do
       owner node['owner_name']
       group node['owner_name']
       mode 0600
       source "dhparam.erb"
       variables ({
         :dhparam => app.metadata('dh_key')
       })
       notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
    end
  end

  directory "/data/nginx/servers/#{app.name}" do
    owner node['owner_name']
    group node['owner_name']
    mode 0775
  end

  directory "/data/nginx/servers/#{app.name}/ssl" do
    owner node['owner_name']
    group node['owner_name']
    mode 0775
  end

  file "/data/nginx/servers/#{app.name}/custom.conf" do
    action :create_if_missing
    owner node.engineyard.environment.ssh_username
    group node.engineyard.environment.ssh_username
    mode 0644
  end

  managed_template "/data/nginx/servers/#{app.name}.users" do
    owner node['owner_name']
    group node['owner_name']
    mode 0644
    source "users.erb"
    variables({
      :application => app
    })
    notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
  end

=begin TODOv6
  mongrel_service = find_app_service(app, "mongrel")
  fcgi_service = find_app_service(app, "fcgi")
  mongrel_base_port =  (mongrel_service[:mongrel_base_port].to_i + (index * 200))
  unicorn = app.recipes.include?('unicorn')
  php = app.recipes.include?('php')

#
# HAX for SD-4650
# Remove it when awsm stops using dnapi to generate the dna and allows configure ports

  meta = node.engineyard.apps.detect {|a| a.metadata?(:nginx_http_port) }
  nginx_http_port = ( meta and meta.metadata?(:nginx_http_port) ) || 8081
=end
  nginx_http_port = 8081


  managed_template "/etc/nginx/listen_http.port" do
    owner node['owner_name']
    group node['owner_name']
    mode 0644
    source "listen-http.erb"
    variables({
        :http_bind_port => nginx_http_port,
    })
    notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
  end

  # CC-260: Chef 10 could not handle two managed template blocks using the same
  # name with different ifs, so since this can be determined during compile
  # time values, we can use just a regular if statement

  #if stack.match(mongrel_unicorn)
    managed_template "/data/nginx/servers/#{app.name}.conf" do
      owner node['owner_name']
      group node['owner_name']
      mode 0644
      source "server.conf.erb"
      variables(
        lazy {
          {
            :application => app,
            :app_name   => app.name,
            :http_bind_port => nginx_http_port,
            :server_names => app.vhosts.first.domain_name.empty? ? [] : [app.vhosts.first.domain_name],
			      :http2 => node['nginx']['http2']
          }
        }
      )
      notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
    end
  #end
=begin
  # if there is an ssl vhost
  if app.https?

    # Can be removed when no one is on nodejs-v2 stack
    file "/data/nginx/servers/#{app.name}.custom.ssl.conf" do
      action :delete
    end

    file "/data/nginx/servers/#{app.name}/custom.ssl.conf" do
      action :create_if_missing
      owner node.engineyard.environment.ssh_username
      group node.engineyard.environment.ssh_username
      mode 0644
    end

    template "/data/nginx/ssl/#{app.name}.key" do
      owner node['owner_name']
      group node['owner_name']
      mode 0644
      source "sslkey.erb"
      backup 0
      variables(
        :key => app[:vhosts][1][:key]
      )
      notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
    end

    template "/data/nginx/ssl/#{app.name}.crt" do
      owner node['owner_name']
      group node['owner_name']
      mode 0644
      source "sslcrt.erb"
      backup 0
      variables(
        :crt => app[:vhosts][1][:crt],
        :chain => app[:vhosts][1][:chain]
      )
      notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
    end

    # Uses Nginx include chain to reduce the dependancy on keepfiles
    # Main(override)->Customer->Default

      # Add certificate chain
      template "/data/nginx/servers/#{app.name}/default.ssl_cert" do
        owner node['owner_name']
        group node['owner_name']
        mode 0644
        source "default_ssl_cert.erb"
        backup 3
        variables(
          :app_name   => app.name
        )
        notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
      end

      # Add Cipher chain
      template "/data/nginx/servers/#{app.name}/default.ssl_cipher" do
        owner node['owner_name']
        group node['owner_name']
        mode 0644
        source "default_ssl_cipher.erb"
        backup 3
        variables(
          :app_name => app.name,
          :tlsv12_available => tlsv12_available,
          :dhparam_available => dhparam_available
        )
        notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
      end

    # Chain files are create if missing and do not reload Nginx
    # Add certificate chain
    template "/data/nginx/servers/#{app.name}/customer.ssl_cert" do
      owner node['owner_name']
      group node['owner_name']
      mode 0644
      source "customer_ssl_cert.erb"
      action :create_if_missing
      variables(
        :app_name   => app.name,
        :tlsv12_available => tlsv12_available,
        :dhparam_available => dhparam_available
      )
    end

    # Add Cipher chain
    template "/data/nginx/servers/#{app.name}/customer.ssl_cipher" do
      owner node['owner_name']
      group node['owner_name']
      mode 0644
      source "customer_ssl_cipher.erb"
      action :create_if_missing
      variables(
        :app_name => app.name
      )
    end
    # Add certificate chain
    template "/data/nginx/servers/#{app.name}/ssl_cert" do
      owner node['owner_name']
      group node['owner_name']
      mode 0644
      source "main_ssl_cert.erb"
      action :create_if_missing
      variables(
        :app_name   => app.name
      )
    end

    # Add Cipher chain
    template "/data/nginx/servers/#{app.name}/ssl_cipher" do
      owner node['owner_name']
      group node['owner_name']
      mode 0644
      source "main_ssl_cipher.erb"
      action :create_if_missing
      variables(
        :app_name => app.name
      )
    end

    # PHP SSL template
    if stack.match(php_fpm)
      managed_template "/data/nginx/servers/#{app.name}.ssl.conf" do
        owner node['owner_name']
        group node['owner_name']
        mode 0644
        source "fpm-ssl.conf.erb"
        variables({
          :application => app,
          :app_name   => app.name,
          :http_bind_port => nginx_http_port,
          :server_names =>  app[:vhosts][1][:name].empty? ? [] : [app[:vhosts][1][:name]],
          :webroot => php_webroot,
          :env_name => node.engineyard.environment[:name]
        })
        notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
      end

      managed_template "/etc/nginx/servers/#{app.name}/additional_server_blocks.ssl.customer" do
        owner node['owner_name']
        group node['owner_name']
        mode 0644
        variables({
          :app_name   => app.name,
          :server_name => (app.vhosts.first.domain_name.empty? or app.vhosts.first.domain_name == "_") ? "www.domain.com" : app.vhosts.first.domain_name,
        })
        source "additional_server_blocks.ssl.customer.erb"
        not_if { File.exists?("/etc/nginx/servers/#{app.name}/additional_server_blocks.ssl.customer") }
      end
      managed_template "/etc/nginx/servers/#{app.name}/additional_location_blocks.ssl.customer" do
        owner node['owner_name']
        group node['owner_name']
        mode 0644
        source "additional_location_blocks.ssl.customer.erb"
        not_if { File.exists?("/etc/nginx/servers/#{app.name}/additional_location_blocks.ssl.customer") }
      end
    end

    template "/data/nginx/ssl/#{app.name}.pem" do
      owner node['owner_name']
      group node['owner_name']
      mode 0644
      source "sslpem.erb"
      backup 0
      variables(
        :crt => app[:vhosts][1][:crt],
        :chain => app[:vhosts][1][:chain],
        :key => app[:vhosts][1][:key]
      )
      notifies :run, resources(:execute => 'reload-haproxy'), :delayed
    end

    # CC-260: Same issue as previous; using compile-time if rather than run-time only_if directive
    if stack.match(mongrel_unicorn)
      managed_template "/data/nginx/servers/#{app.name}.ssl.conf" do
        owner node['owner_name']
        group node['owner_name']
        mode 0644
        source "ssl.conf.erb"
        variables(
          lazy {
            {
              :unicorn   => unicorn,
              :application => app,
              :app_name   => app.name,
              :app_type => app.app_type,
              :mongrel_base_port => mongrel_base_port,
              :mongrel_instance_count => [1, recipe.get_pool_size / node.dna[:applications].size].max,
              :http_bind_port => nginx_http_port,
              :server_names =>  app[:vhosts][1][:name].empty? ? [] : [app[:vhosts][1][:name]],
              :fcgi_pass_port => fcgi_service[:fcgi_pass_port],
              :fcgi_mem_limit => fcgi_service[:fcgi_mem_limit],
              :fcgi_instance_count => fcgi_service[:fcgi_instance_count],
              :use_msec => use_msec
            }
          }
        )
        notifies node['nginx'][:action], resources(:service => "nginx"), :delayed
      end
      managed_template "/etc/nginx/servers/#{app.name}/additional_server_blocks.ssl.customer" do
        owner node['owner_name']
        group node['owner_name']
        mode 0644
        variables({
          :app_name   => app.name,
          :server_name => (app.vhosts.first.domain_name.empty? or app.vhosts.first.domain_name == "_") ? "www.domain.com" : app.vhosts.first.domain_name,
        })
        source "additional_server_blocks.ssl.customer.erb"
        not_if { File.exists?("/etc/nginx/servers/#{app.name}/additional_server_blocks.ssl.customer") }
      end
      managed_template "/etc/nginx/servers/#{app.name}/additional_location_blocks.ssl.customer" do
        owner node['owner_name']
        group node['owner_name']
        mode 0644
        source "additional_location_blocks.ssl.customer.erb"
        not_if { File.exists?("/etc/nginx/servers/#{app.name}/additional_location_blocks.ssl.customer") }
      end
    end
  else
    execute "ensure-no-old-ssl-vhosts-for-#{app.name}" do
      command %Q{
        rm -f /data/nginx/servers/#{app.name}.ssl.conf;true
      }
    end
  end
=end
end

=begin TODOv6
service "nginx" do
  supports :status => true, :restart => true, :reload => true
  action [ :start, :enable ]
end
=end
