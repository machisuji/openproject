class WorkPackageField
  include Capybara::DSL
  include RSpec::Matchers

  attr_reader :page, :element

  def initialize(page, property_name, selector = nil)
    @page = page
    @property_name = property_name

    if selector.nil?
      if property_name == :'start-date' || property_name == :'end-date'
        @selector = '.work-package-field.work-packages--details--date'
      else
        @selector = ".work-package-field.work-packages--details--#{@property_name}"
      end
    else
      @selector = selector
    end

    ensure_page_loaded

    @element = page.find(field_selector)
  end

  def expect_state_text(text)
    expect(@element).to have_selector('.inplace-edit--read-value', text: text)
  end

  def trigger_link
    @element.find trigger_link_selector
  end

  def trigger_link_selector
    'a.inplace-editing--trigger-link'
  end

  def field_selector
    @selector
  end

  def activate_edition
    tag = element.find("#{trigger_link_selector}, #{input_selector}")

    if tag.tag_name == 'a'
      tag.click
    end
    # else do nothing as the element is already in edit mode
  end

  def input_element
    if custom_field?
      custom_field_input
    else
      @element.find input_selector
    end
  end

  def custom_field?
    field_selector =~ /customField\d+$/
  end

  def submit_by_click
    @element.find('.inplace-edit--control--save > a', wait: 5).click
  end

  def submit_by_enter
    input_element.native.send_keys :return
  end

  def cancel_by_click
    cancel_link_selector = '.inplace-edit--control--cancel a'
    if @element.has_selector?(cancel_link_selector)
      @element.find(cancel_link_selector).click
    end
  end

  def cancel_by_escape
    input_element.native.send_keys :escape
  end

  def editable?
    trigger_link.visible? rescue false
  end

  def editing?
    @element.find('.inplace-edit--write').visible? rescue false
  end

  def errors_text
    @element.find('.inplace-edit--errors--text').text
  end

  def errors_element
    @element.find('.inplace-edit--errors')
  end

  def ensure_page_loaded
    if Capybara.current_driver == Capybara.javascript_driver
      extend ::Angular::DSL unless singleton_class.included_modules.include?(::Angular::DSL)
      ng_wait

      expect(page).to have_selector('.work-packages--details--subject')
    end
  end

  private

  def input_selector
    if custom_field?
      ".inplace-edit--write-value"
    else
      selector = { :'start-date' => 'date-start',
                   :'end-date' => 'date-end' }[@property_name] || @property_name

      "#inplace-edit--write-value--#{selector}"
    end
  end

  def custom_field_input
    klass = field_selector.split(".").last

    page
      .find(:xpath, "//*[contains(@class, '#{klass}')]//*[contains(@title, ': Edit')]")
  end
end
