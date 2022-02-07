wazuh = node['wazuh-manager']

group wazuh['group'] do
end

execute 'curl_docker' do
  command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -"
end

execute 'install_packages' do
  command "apt-get update && apt-get -y install zip apt-transport-https ca-certificates curl software-properties-common docker docker-compose"
end

#execute 'remove_nginx_haproxy' do
#  command "apt -y remove haproxy nginx"
#end

directory "/opt/wazuh-manager" do
  owner wazuh['user']
  group wazuh['group']
  mode '0755'
  action :create
end

execute 'extract wazuh-manager' do
  command "unzip /tmp/wazuh-manager.zip -d /opt/wazuh-manager"
  user wazuh['user']
  group wazuh['group']
  not_if { ::File.exists?("/opt/wazuh-manager/wazuh-docker-master") }
  action :run
end

node['dna']['applications'].each do |app_name, data|
execute 'stop apps' do
  user node['owner_name']
  group node['owner_name']
  command "/engineyard/bin/app_#{app_name} stop"
  action :run
end
end

execute 'remove_default_site' do
  command 'rm -rf /etc/nginx'
  user wazuh['user']
  group wazuh['group']
end

#execute 'stop_disable_nginx' do
#  command 'systemctl stop nginx && systemctl disable nginx && rm /lib/systemd/system/nginx.service'
#  user wazuh['user']
#  group wazuh['group']
#end

#execute 'stop_disable_haproxy' do
#  command 'systemctl stop haproxy && systemctl disable haproxy && rm /lib/systemd/system/haproxy.service'
#  user wazuh['user']
#  group wazuh['group']
#end

execute 'stop_disable_haproxy' do
  command '/etc/init.d/haproxy stop'
  user wazuh['user']
  group wazuh['group']
end

template "/opt/wazuh-manager/wazuh-docker-master/docker-compose.yml" do
  source 'docker-compose.erb'
  mode '0755'
  variables(
    :user => wazuh['username-password']
  )
end


if wazuh['force-restart']
  execute 'kill-previous-containers' do
    cwd "/opt/wazuh-manager/wazuh-docker-master"
    command "docker stop -t  1 $(docker ps -a |awk {'print $1'} |grep -v CONTAINER) && docker system prune -f && docker-compose up -d"
    user wazuh['user']
    group wazuh['group']
  end
end

execute 'stop_disable_nginx' do
  command '/etc/init.d/nginx stop'
  user wazuh['user']
  group wazuh['group']
end

execute 'set_v_memory' do
  command 'sysctl -w vm.max_map_count=262144'
  user wazuh['user']
  group wazuh['group']
end

execute 'start_docker' do
  cwd "/opt/wazuh-manager/wazuh-docker-master"
  command "docker-compose up -d"
  user wazuh['user']
  group wazuh['group']
  action :run
  not_if "docker ps -a |grep wazuhdockermaster_wazuh"
end