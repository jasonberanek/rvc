include RVC::Util

opts :type do
  summary "Display information about a VMODL type"
  arg :name, "VMODL type name"
end

def type name
  klass = RbVmomi::VIM.type(name) rescue err("invalid type #{name.inspect}")
  q = lambda { |x| x =~ /^xsd:/ ? $' : x }
  if klass < RbVmomi::VIM::DataObject
    puts "Data Object #{klass}"
    klass.full_props_desc.each do |desc|
      puts " #{desc['name']}: #{q[desc['wsdl_type']]}#{desc['is-array'] ? '[]' : ''}"
    end
  elsif klass < RbVmomi::VIM::ManagedObject
    puts "Managed Object #{klass}"
    puts
    puts "Properties:"
    klass.full_props_desc.each do |desc|
      puts " #{desc['name']}: #{q[desc['wsdl_type']]}#{desc['is-array'] ? '[]' : ''}"
    end
    puts
    puts "Methods:"
    klass.full_methods_desc.sort_by(&:first).each do |name,desc|
      params = desc['params']
      puts " #{name}(#{params.map { |x| "#{x['name']} : #{q[x['wsdl_type'] || 'void']}#{x['is-array'] ? '[]' : ''}" } * ', '}) : #{q[desc['result']['wsdl_type'] || 'void']}"
    end
  else
    err("cannot introspect type #{klass}")
  end
  nil
end

opts :help do
  summary "Display this text"
end

HELP_ORDER = %w(basic vm)

def help
  puts (<<-EOS)
Available commands:
  EOS

  MODULES.sort_by do |mod_name,mod|
    HELP_ORDER.index(mod_name) || HELP_ORDER.size
  end.each do |mod_name,mod|
    opts = mod.instance_variable_get(:@opts)
    opts.each do |method_name,method_opts|
      parser = RVC::OptionParser.new method_name, &method_opts
      aliases = ALIASES.select { |k,v| v == "#{mod_name}.#{method_name}" }.keys
      aliases_text = aliases.empty? ? '' : " (#{aliases*', '})"
      puts "#{mod_name}.#{method_name}#{aliases_text}: #{parser.summary?}" if parser.summary?
    end
  end

  puts (<<-EOS)

To see detailed help for a command, use its --help option.
  EOS
end

opts :debug do
  summary "Toggle VMOMI logging to stderr"
end

def debug
  $vim.debug = !$vim.debug
end

opts :quit do
  summary "Exit RVC"
end

def quit
  exit
end

opts :rc do
  summary "Reread ~/.rvcrc"
end

def rc
  RVC.reload_rc
end

opts :reload do
  summary "Reload RVC command modules"
end

def reload
  RVC.reload_modules
end

opts :cd do
  summary "Change directory"
  arg :path, "Directory to change to"
end

def cd path
  $context.cd path
end

opts :ls do
  summary "List objects in a directory"
  arg :path, "Directory to list", :required => false, :default => '.'
end

def ls path
  loc = $context.lookup_loc(path)
  obj = loc.obj
  children = obj.children
  name_map = children.invert
  children, fake_children = children.partition { |k,v| v.is_a? VIM::ManagedEntity }
  i = 0

  fake_children.each do |name,obj|
    puts "#{i} #{name}#{obj.ls_text(nil)}"
    mark_loc = loc.dup.tap { |x| x.push name, obj }
    $context.mark i.to_s, mark_loc
    i += 1
  end

  return if children.empty?

  filterSpec = VIM.PropertyFilterSpec(:objectSet => [], :propSet => [])
  filteredTypes = Set.new

  children.each do |name,obj|
    filterSpec.objectSet << { :obj => obj }
    filteredTypes << obj.class
  end

  filteredTypes.each do |x|
    filterSpec.propSet << {
      :type => x.wsdl_name,
      :pathSet => x.ls_properties+%w(name),
    }
  end

  results = $vim.propertyCollector.RetrieveProperties(:specSet => [filterSpec])

  results.each do |r|
    name = name_map[r.obj]
    text = r.obj.ls_text r
    realname = r['name'] if name != r['name']
    puts "#{i} #{name}#{realname && " [#{realname}]"}#{text}"
    mark_loc = loc.dup.tap { |x| x.push name, r.obj }
    $context.mark i.to_s, mark_loc
    i += 1
  end
end

opts :info do
  summary "Display information about an object"
  arg :path, "Any object"
end  

def info path
  obj = lookup(path)
  if obj.respond_to? :display_info
    obj.display_info
  else
    puts "class: #{obj.class.name}"
  end
end

opts :destroy do
  summary "Destroy managed entities"
  arg :path, "Managed entities", :multi => true
end

def destroy paths
  progress paths, :Destroy
end

opts :mark do
  summary "Save a path for later use"
  arg :key, "Name for this mark"
  arg :path, "Any object", :required => false, :default => '.'
end

def mark key, path
  err "invalid mark name" unless key =~ /^\w+$/
  $context.mark key, $context.lookup_loc(path)
end
