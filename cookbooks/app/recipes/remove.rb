Chef::EY::Application.all( node,
                           ( node.dna['removed_applications'] ? node.dna['removed_applications'] : [] ) ).each do |app|
  directory app.path do
    action :delete
    recursive true
  end
end
