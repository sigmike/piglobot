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

require 'rubygems'
require "ruby-debug"

ARGV.replace %w(
  inactive_admins_spec.rb
  piglobot_spec.rb
  editor_spec.rb
  tools_spec.rb
  wiki_spec.rb
  job_spec.rb
  job_lann_spec.rb
  parser_spec.rb
  suivi_portail_informatique_spec.rb
  infobox_rewriter_spec.rb
  homonym_prevention_spec.rb
  change_spec.rb
  user_category_spec.rb
  mediawiki_spec.rb
) if ARGV.empty?
ARGV << "--diff"

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/rspec/rspec/lib"))
require 'spec'

exit ::Spec::Runner::CommandLine.run(rspec_options)
