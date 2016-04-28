#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

class WorkPackage::PdfExport::WorkPackageToPdf
  include Redmine::I18n
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::NumberHelper
  include CustomFieldsHelper
  include WorkPackage::PdfExport::ToPdfHelper

  attr_accessor :work_package,
                :pdf

  def initialize(work_package)
    self.work_package = work_package

    self.pdf = get_pdf(current_language)
  end

  def make_attribute_row(first_attribute, second_attribute)
    [
      make_attribute_cells(
        first_attribute, label_options: { borders: [:left] },
                         value_options: { borders: [] }
      ),
      make_attribute_cells(
        second_attribute, label_options: { borders: [:left] },
                          value_options: { borders: [:right] }
      )
    ]
      .flatten
  end

  def make_attribute_cells(attribute, label_options: {}, value_options: {})
    label = pdf.make_cell(
      WorkPackage.human_attribute_name(attribute) + ':',
      label_options)

    value_content = work_package.send(attribute)
    value_content = format_date value_content if attribute.to_s =~ /_at$/

    value = pdf.make_cell(value_content.to_s, value_options)

    [label, value]
  end

  def make_attributes
    attrs = [
      [:status, :priority],
      [:author, :category],
      [:created_at, :assigned_to],
      [:updated_at, :due_date]
    ]

    attrs.map do |first, second|
      make_attribute_row first, second
    end
  end

  def make_custom_fields
    work_package.custom_field_values.map do |custom_value|
      label = pdf.make_cell custom_value.custom_field.name + ':',
                            borders: [:left]
      value = pdf.make_cell show_value(custom_value),
                            colspan: 3,
                            borders: [:right]
      [label, value]
    end
  end

  def make_description
    label = pdf.make_cell(WorkPackage.human_attribute_name(:description) + ':',
                          borders: [:left, :bottom])
    value = pdf.make_cell work_package.description.to_s,
                          colspan: 3,
                          borders: [:bottom, :right]
    [[label, value]]
  end

  def show_history?
    work_package.changesets.any? &&
      User.current.allowed_to?(:view_changesets, work_package.project)
  end

  def newline!
    pdf.move_down 4
  end

  def render!
    pdf.title = "#{work_package.project} - ##{work_package.type} #{work_package.id}"
    pdf.footer_date = format_date(Date.today)
    pdf.font style: :bold, size: 11
    pdf.text "#{work_package.project} - #{work_package.type} # #{work_package.id}: #{work_package.subject}"
    pdf.move_down 20

    data = make_attributes

    data.first.each { |cell| cell.borders << :top } # top horizontal line
    data.last.each { |cell| cell.borders << :bottom } # horizontal line after main attrs

    make_custom_fields.each { |row| data << row }
    make_description.each { |row| data << row }

    pdf.font style: :normal, size: 9

    pdf.table(data, width: pdf.bounds.width - 1) do
      cells.padding = [2, 5, 2, 5]
    end

    if show_history?
      newline!

      pdf.font style: :bold, size: 9
      pdf.text I18n.t(:label_associated_revisions)
      pdf.stroke do
        pdf.horizontal_rule
      end
      newline!

      for changeset in work_package.changesets
        pdf.font style: :bold, size: 8
        pdf.text(format_time(changeset.committed_on) + ' - ' + changeset.author.to_s)
        newline!

        if changeset.comments.present?
          pdf.font style: :normal, size: 8
          pdf.text changeset.comments.to_s
        end

        newline!
      end
    end

    pdf.move_down(pdf.font_size * 2)

    pdf.font style: :bold, size: 9
    pdf.text I18n.t(:label_history)
    pdf.stroke do
      pdf.horizontal_rule
    end

    newline!

    for journal in work_package.journals.includes(:user).order("#{Journal.table_name}.created_at ASC")
      next if journal.initial?

      pdf.font style: :bold, size: 8
      pdf.text(format_time(journal.created_at) + ' - ' + journal.user.name)
      newline!

      pdf.font style: :italic, size: 8
      for detail in journal.details
        text = journal
          .render_detail(detail, no_html: true, only_path: false)
          .gsub(/\((https?[^\)]+)\)$/, "(<link href='\\1'>\\1</link>)")
        pdf.text('- ' + text, inline_format: true)
        newline!
      end

      if journal.notes?
        newline unless journal.details.empty?

        pdf.font style: :normal, size: 8
        pdf.text journal.notes.to_s
      end

      newline!
    end

    if work_package.attachments.any?
      pdf.move_down(pdf.font_size * 2)

      pdf.font style: :bold, size: 9
      pdf.text I18n.t(:label_attachment_plural)
      pdf.stroke do
        pdf.horizontal_rule
      end
      newline!

      pdf.font style: :normal, size: 8

      data = work_package.attachments.map do |attachment|
        [
          attachment.filename,
          number_to_human_size(attachment.filesize),
          format_date(attachment.created_on),
          attachment.author.name
        ]
      end

      max_width = pdf.bounds.width

      pdf.table(data, width: max_width - 1) do
        cells.padding = [2, 5, 2, 5]
        cells.borders = []

        column(0).width = (max_width * 0.5).to_i
        column(1).align = :right
        column(3).align = :right
      end
    end

    pdf
  end
end
