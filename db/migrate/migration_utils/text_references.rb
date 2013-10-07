# OpenProject is a project management system.
#
# Copyright (C) 2012-2013 the OpenProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require_relative 'utils'

module Migration
  module Utils
    def update_text_references(table, columns)
      id_update_map = planning_element_to_work_package_id_map

      update_column_values(table,
                           columns,
                           process_text_update(columns, id_update_map),
                           update_filter(columns))
    end

    def restore_text_references(table, columns)
      id_restore_map = work_package_to_planning_element_id_map

      update_column_values(table,
                           columns,
                           process_text_restore(columns, id_restore_map),
                           restore_filter(columns))
    end

    private

    def planning_element_to_work_package_id_map
      create_planning_element_id_map 'id', 'new_id'
    end

    def work_package_to_planning_element_id_map
      create_planning_element_id_map 'new_id', 'id'
    end

    def create_planning_element_id_map(key, value)
      old_and_new_ids = select_all <<-SQL
        SELECT id, new_id, project_id
        FROM legacy_planning_elements
      SQL

      old_and_new_ids.each_with_object({}) do |row, hash|
        current_id = row[key]
        new_id = row[value]
        project_id = row['project_id']

        hash[current_id] = { new_id: new_id, project_id: project_id}
      end
    end

    def process_text_update(columns, id_map)
      Proc.new do |row|
        columns.each do |column|
          row[column] = update_work_package_macros row[column], id_map, MACRO_REGEX, /\*/, '#'
          row[column] = update_issue_planning_element_links row[column], id_map
        end

        row
      end
    end

    def process_text_restore(columns, id_map)
      Proc.new do |row|
        columns.each do |column|
          row[column] = update_work_package_macros row[column], id_map, RESTORE_MACRO_REGEX, /#/, '*'
          row[column] = restore_issue_planning_element_links row[column], id_map
        end

        row
      end
    end

    MACRO_REGEX = /(?<dots>\*{1,3})(?<id>\d+)/
    RESTORE_MACRO_REGEX = /(?<dots>\#{1,3})(?<id>\d+)/

    def update_work_package_macros(text, id_map, regex, macro_regex, new_macro)
      unless text.nil?
        text.gsub!(regex) do |match|
          if id_map.has_key? $~[:id].to_s
            new_id = id_map[$~[:id].to_s][:new_id]
            hash_macro = $~[:dots].gsub(macro_regex, new_macro)

            "#{hash_macro}#{new_id}"
          end
        end
      end

      text
    end

    def update_issue_planning_element_links(text, id_map)
      unless text.nil?
        text.gsub!(work_package_link_regex) {|_| update_issue_planning_element_link_match $~, id_map}
        text.gsub!(rel_work_package_link_regex) {|_| update_issue_planning_element_link_match $~, id_map}
      end

      text
    end

    def work_package_link_regex
      @work_package_link_regex ||= Regexp.new "(?<host>http(s)?:\/\/#{Regexp.escape(host_name)})(\/timelines)?(\/projects\/(\\w|-)*)?\/(issues|planning_elements)\/(?<id>\\w*)"
    end

    def rel_work_package_link_regex
      @rel_work_package_link_regex ||= Regexp.new "(?<title>\"(\\w|\\s)*\"):#{Regexp.escape(host_postfix)}(\/timelines)?(\/projects\/(\\w|-)*)?\/(issues|planning_elements)\/(?<id>\\w*)"
    end

    def restore_issue_planning_element_links(text, id_map)
      unless text.nil?
        text.gsub!(restore_work_package_link_regex) {|_| restore_issue_planning_element_link_match $~, id_map}
        text.gsub!(restore_rel_work_package_link_regex) {|_| restore_issue_planning_element_link_match $~, id_map}
      end

      text
    end

    def restore_work_package_link_regex
      @restore_work_package_link_regex ||= Regexp.new "(?<host>http(s)?:\/\/#{Regexp.escape(host_name)})\/work_packages\/(?<id>\\w*)"
    end

    def restore_rel_work_package_link_regex
      @restore_rel_work_package_link_regex ||= Regexp.new "(?<title>\"(\\w|\\s)*\"):#{Regexp.escape(host_postfix)}\/work_packages\/(?<id>\\w*)"
    end

    def update_issue_planning_element_link_match(match, id_map)
      "#{link_prefix match}/work_packages/#{element_id match, id_map}"
    end

    def restore_issue_planning_element_link_match(match, id_map)
      if id_map.has_key? match[:id].to_s
        project_id = id_map[match[:id].to_s][:project_id]
        "#{link_prefix match}/timelines/projects/#{project_id}/planning_elements/#{element_id match, id_map}"
      else
        "#{link_prefix match}/issues/#{element_id match, id_map}"
      end
    end

    def link_prefix(match)
      match.names.include?('host') ? match[:host] : "#{match[:title]}:#{host_postfix}"
    end

    def element_id(match, id_map)
      id = match[:id].to_s
      id = id_map[id][:new_id] if id_map.has_key? id
      id
    end

    def host_name
      @host_name ||= select_host_name
    end

    def host_postfix
      @host_postfix ||= select_host_postfix.to_s
    end

    def select_host_name
      settings = select_all <<-SQL
        SELECT value FROM settings WHERE name = 'host_name'
      SQL

      settings.first['value']
    end

    def select_host_postfix
      host_postfix = /[a-z|\.|-]*(\/(?<host_postfix>.*))?/.match(host_name)[:host_postfix]

      host_postfix = "/#{host_postfix}" unless host_postfix.nil?

      host_postfix
    end

    def update_filter(columns)
      filter columns, ['issue', 'planning_element', '*']
    end

    def restore_filter(columns)
      filter columns, ['work_package', '#']
    end

    def filter(columns, terms)
      column_filters = []

      columns.each do |column|
        filters = terms.map {|term| "#{column} LIKE '%#{term}%'"}

        column_filters << "(#{filters.join(' OR ')})"
      end

      column_filters.join(' OR ')
    end
  end
end
