#!/usr/bin/env ruby
require 'json'

list = ''
formatted_list = []
list = `EIX_LIMIT=0 INSTFORMAT='<version> ' eix -I --pure-packages --format '<category>\t<name>\t<installedversions:INSTFORMAT>\t<description>\n'`.split("\n")
list.each do |item|
  i = item.split("\t")
  formatted_list << { category: i[0], name: i[1], version: i[2], description: i[3] } unless ( i[0] == "virtual" || i[0] == "acct-*" )
end
puts JSON.pretty_generate(formatted_list)
