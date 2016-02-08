# encoding: UTF-8
=begin

BETTERCAP

Author : Simone 'evilsocket' Margaritelli
Email  : evilsocket@gmail.com
Blog   : http://www.evilsocket.net/

This project is released under the GPL 3 license.

=end

module BetterCap
module Network
module Protos

class Base
  TYPES = [
      :uint8,
      :uint16,
      :uint32,
      :uint32rev,
      :ip,
      :mac,
      :bytes,
      :string
  ].freeze

  def self.method_missing(method_name, *arguments, &block)
    type = method_name.to_sym
    name = arguments[0]
    if TYPES.include?(type)
      unless self.class_variables.include?(:@@fields)
        class_eval "@@fields = {}"
      end

      class_eval "@@fields[:#{name}] = { :type => :#{type}, :opts => #{arguments.length > 1 ? arguments[1] : {}} }"
      class_eval "attr_accessor :#{name}"
    else
      raise NoMethodError, method_name
    end
  end

  def self.parse( data )
    pkt = self.new

    begin
      offset = 0
      limit  = data.length
      value  = nil

      self.class_variable_get(:@@fields).each do |name, info|
        value = nil

        case info[:type]
        when :uint8
          value = data[offset].ord
          offset += 1

        when :uint16
          value = data[offset..offset + 1].unpack('S')[0]
          offset += 2

        when :uint32
          value = data[offset..offset + 3].unpack('L')[0]
          offset += 4

        when :uint32rev
          value = data[offset..offset + 3].reverse.unpack('L')[0]
          offset += 4

        when :ip
          tmp   = data[offset..offset + 3].reverse.unpack('L')[0]
          value = IPAddr.new(tmp, Socket::AF_INET)
          offset += 4

        when :mac
          tmp   = data[offset..offset + 7]
          value = tmp.bytes.map(&(Proc.new {|x| sprintf('%02X',x) })).join(':')
          offset += size( info, pkt, 16 )

        when :bytes
          size = size( info, pkt, data.length )
          offset = offset( info, pkt, offset  )

          value = data[offset..offset + size - 1].bytes
          offset += size

        when :string
          size = size( info, pkt, data.length )
          offset = offset( info, pkt, offset  )

          value = data[offset..offset + size - 1].bytes.pack('c*')
          if info[:opts].has_key?(:check)
            if value != info[:opts][:check].force_encoding('ASCII-8BIT')
              raise "Unexpected value '#{value}', expected '#{info[:opts][:check]}' ."
            end
          end
          offset += size

        end

        pkt.send("#{name}=", value)
      end

    rescue Exception => e
      #puts e.message
      #puts e.backtrace.join("\n")
      pkt = nil
    end

    pkt
  end

  def self.size( info, pkt, default )
    if info[:opts].has_key?(:size)
      if info[:opts][:size].is_a?(Integer)
        return info[:opts][:size]
      else
        n = pkt.send( info[:opts][:size] )
        return n
      end
    else
      return default
    end
  end

  def self.offset( info, pkt, default )
    if info[:opts].has_key?(:offset)
      if info[:opts][:offset].is_a?(Integer)
        return info[:opts][:offset]
      else
        return default + pkt.send( info[:opts][:offset] )
      end
    else
      return default
    end
  end
end

end
end
end
