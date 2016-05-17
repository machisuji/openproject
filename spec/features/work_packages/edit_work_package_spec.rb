require 'spec_helper'
require 'features/page_objects/notification'

describe 'edit work package', js: true do
  let(:dev_role) do
    FactoryGirl.create :role,
                       permissions: [:view_work_packages,
                                     :add_work_packages]
  end
  let(:dev) do
    FactoryGirl.create :user,
                       firstname: 'Dev',
                       lastname: 'Guy',
                       member_in_project: project,
                       member_through_role: dev_role
  end
  let(:manager_role) do
    FactoryGirl.create :role,
                       permissions: [:view_work_packages,
                                     :edit_work_packages]
  end
  let(:manager) do
    FactoryGirl.create :admin,
                       firstname: 'Manager',
                       lastname: 'Guy',
                       member_in_project: project,
                       member_through_role: manager_role
  end

  let(:cf_all) do
    FactoryGirl.create :work_package_custom_field, is_for_all: true, field_format: 'text'
  end

  let(:cf_tp1) do
    FactoryGirl.create :work_package_custom_field, is_for_all: true, field_format: 'text'
  end

  let(:cf_tp2) do
    FactoryGirl.create :work_package_custom_field, is_for_all: true, field_format: 'text'
  end

  let(:type) { FactoryGirl.create :type, custom_fields: [cf_all, cf_tp1] }
  let(:type2) { FactoryGirl.create :type, custom_fields: [cf_all, cf_tp2] }
  let(:project) { FactoryGirl.create(:project, types: [type, type2]) }
  let(:work_package) { FactoryGirl.create(:work_package, author: dev, project: project, type: type) }

  let(:new_subject) { 'Some other subject' }
  let(:wp_page) { Pages::FullWorkPackage.new(work_package) }
  let(:priority2) { FactoryGirl.create :priority }
  let(:status2) { FactoryGirl.create :status }
  let(:workflow) do
    FactoryGirl.create :workflow,
                       type_id: type2.id,
                       old_status: work_package.status,
                       new_status: status2,
                       role: manager_role
  end
  let(:version) { FactoryGirl.create :version, project: project }
  let(:category) { FactoryGirl.create :category, project: project }

  before do
    login_as(manager)

    manager
    dev
    priority2
    workflow

    wp_page.visit!
  end

  it 'allows updating and seeing the results' do
    wp_page.ensure_page_loaded

    wp_page.view_all_attributes

    wp_page.update_attributes type: type2.name,
                              :'start-date' => '2013-03-04',
                              :'end-date' => '2013-03-20',
                              responsible: manager.name,
                              assignee: manager.name,
                              estimatedTime: '5.00',
                              percentageDone: '30',
                              subject: 'a new subject',
                              description: 'a new description',
                              priority: priority2.name,
                              status: status2.name,
                              version: version.name,
                              category: category.name

    wp_page.expect_notification message: I18n.t('js.notice_successful_update')

    wp_page.expect_attributes Type: type2.name,
                              Responsible: manager.name,
                              Assignee: manager.name,
                              Date: '03/04/2013 - 03/20/2013',
                              'Estimated time' => '5.00',
                              Progress: '30',
                              Subject: 'a new subject',
                              Description: 'a new description',
                              Priority: priority2.name,
                              Status: status2.name,
                              Version: version.name,
                              Category: category.name
  end

  it 'allows the user to add a comment to a work package with previewing the stuff before' do
    wp_page.ensure_page_loaded

    wp_page.trigger_edit_comment
    wp_page.update_comment 'hallo welt'
    wp_page.preview_comment

    expect(page).to have_text 'hallo welt'

    wp_page.save_comment

    expect(page).to have_text 'hallo welt'
  end

  it 'keeps the inserted value when the type is switched' do
    wp_page.ensure_page_loaded
    wp_page.view_all_attributes

    wp_page.trigger_edit_mode
    wp_page.set_attributes responsible: manager.name,
                           type: type2.name
    wp_page.save!

    wp_page.expect_notification message: I18n.t('js.notice_successful_update')
    wp_page.expect_attributes 'Responsible' => manager.name
  end

  it 'updates the presented custom fields based on the selected type' do
    wp_page.ensure_page_loaded
    wp_page.view_all_attributes

    wp_page.expect_attributes cf_all.name => '',
                              cf_tp1.name => ''
    wp_page.expect_attribute_hidden cf_tp2.name

    wp_page.trigger_edit_mode

    wp_page.set_attributes "customField#{cf_all.id}" => 'bird is the word',
                           'type' => type2.name

    wp_page.save!
    wp_page.view_all_attributes

    wp_page.expect_attributes cf_all.name => 'bird is the word',
                              cf_tp2.name => ''
    wp_page.expect_attribute_hidden cf_tp1.name
  end

  it 'shows an error if a subject is entered which is too long' do
    too_long = ("Too long. Can you feel it? " * 10).strip

    wp_page.ensure_page_loaded
    wp_page.update_attributes subject: too_long

    wp_page.expect_notification message: 'Subject is too long (maximum is 255 characters)',
                                type: 'error'
  end
end
