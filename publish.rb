#!/usr/bin/env ruby

=begin
    Copyright (c) 2007 by Piglop
    This file is part of Piglobot.

    Piglobot is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Piglobot is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Piglobot.  If not, see <http://www.gnu.org/licenses/>.
=end

Dir.chdir File.dirname(__FILE__)
require 'piglobot'

repos = ARGV[0]
rev = ARGV[1]

raise "usage: #$0 <repos> <rev>" unless repos and rev

comment = %x(svnlook log #{repos} -r#{rev})
comment = comment.split("\n").select { |line| !line.empty? }.join(" - ")

bot = Piglobot.new
bot.notice("{{user:Piglobot/Rev|#{rev}|#{comment}}}")

