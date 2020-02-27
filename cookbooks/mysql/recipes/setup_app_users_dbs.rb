node.engineyard.apps.each do |app|

  dbhost = (node['dna']['db_hostF'] == 'localhost' ? 'localhost' : '%')

  short_version = node['mysql']['short_version']
  if short_version == '8.0'
    config_postfix = '80'
  else
    config_postfix = ''
  end

  template "/tmp/create.#{app.database_name}.sql" do
    owner 'root'
    group 'root'
    mode 0644
    source "create#{config_postfix}.sql.erb"
    variables({
      :dbuser => app.database_username,
      :dbpass => app.database_password,
      :dbname => app.database_name,
      :dbhost => dbhost,
    })
  end

  execute "remove-database-file-for-#{app.database_name}" do
    command %Q{
      rm /tmp/create.#{app.database_name}.sql
    }
    action :nothing
  end

  execute "create-database-for-#{app.database_name}" do
    command %Q{
      mysql -u #{node.engineyard.environment['db_admin_username']} -p'#{node.engineyard.environment['db_admin_password']}' < /tmp/create.#{app.database_name}.sql
    }
    notifies(:run, resources(:execute => "remove-database-file-for-#{app.database_name}"))
  end
end
