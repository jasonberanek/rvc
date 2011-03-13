module RVC

module InventoryObject
  module ClassMethods
    def ls_properties
      %w()
    end

    def folder?
      false
    end
  end

  def self.included m
    m.extend ClassMethods
  end

  def display_info
    puts "name: #{name}"
    puts "type: #{self.class.name}"
  end

  def ls_text r
    self.class.folder? ? '/' : ''
  end

  def child_types
    children.map { |k,v| [k, v.class] }
  end

  def traverse_one arc
    children[arc]
  end

  def children
    {}
  end

  def parent
    nil
  end
end

class FakeFolder
  include RVC::InventoryObject

  def initialize target, method
    @target = target
    @method = method
  end

  def children
    @target.send @method
  end

  def self.folder?
    true
  end

  def parent
    @target
  end
end

end
