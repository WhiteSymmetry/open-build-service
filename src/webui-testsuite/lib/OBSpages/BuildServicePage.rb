# ==============================================================================
# BuildServicePage is an abstract class that represents all common functionality
# of Open Build Service pages like header, footer, breadcrumb etc.
# @abstract
#
class BuildServicePage < WebPage  

  ATTRIBUTES = [ "NSTEST:status",
                 "OBS:VeryImportantProject",
                 "OBS:UpdateProject",
                 "OBS:Maintained",
                 "OBS:RequestCloned",
                 "OBS:InitializeDevelPackage",
                 "OBS:MaintenanceProject",
                 "OBS:MaintenanceIdTemplate",
                 "OBS:RejectRequests",
                 "OBS:ApprovedRequestSource",
                 "OBS:BranchTarget",
                 "OBS:ScreenShots",
                 "OBS:ProjectStatusPackageFailComment",
                 "OBS:QualityCategory" ].sort

  # ============================================================================
  # (see WebPage#validate_page)
  #

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    res = wait_for_page
    assert_equal res.shift["id"], "header-logo"
    assert_equal res.shift.text, "openSUSE Build Service"
    assert_equal current_user, @user
    assert_equal @driver.current_url, @url
  end
  
  
  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    #puts "#{self.class}.initialize #{options.inspect}"
    @user = options[:user]
  end
  
  
  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    #puts "#{self.class}.initialize_ready #{current_user.inspect}"
    @user = current_user
  end
  

  # ============================================================================
  # Restores the browser to the correct page. Assumes that the object has
  # been initialized properly and all needed page variables are defined.
  # @note In case that the expected user isn't strictly specified 
  #   this method assigns @user to the currently logged user.
  #
  def restore
    super
    #puts "#{self.class}.restore #{@user.inspect}"
    @driver.get @url
    wait_for_page
    if @user.nil? then
      @user = current_user
    elsif @user != current_user then
      user = if @user == :none then :none else @user.clone end
      if user_is_logged? then
        logout
        @driver.get @url
      end
      login_as user unless user == :none
    end
  end
  
  
  # ============================================================================
  # Logs in with the given username and password.
  # @param [Hash] user the user credentials to be used for the login,
  #   must be a hash of with the following keys:  
  #   { :login=>String , :password=>String }
  # @param [:success, :error] expect the expected result from the action
  #
  def login_as user, expect = :success
    assert([:success,:error,:admin].include? expect)
    validate { !user_is_logged? }

    @driver[:id => "login-trigger"].click
    @driver[:id => "username"].clear
    @driver[:id => "username"].send_keys user[:login]
    @driver[:id => "password"].clear
    @driver[:id => "password"].send_keys user[:password]
    @driver[:xpath => "//div[@id='login-form']
      //input[@name='commit'][@value='Login']"].click

    if expect == :admin || expect == :success
      @user = user
      
      validate { user_is_logged? }      
      if expect == :admin && is_interconnect_page?
	 $page = InterconnectPage.new_ready @driver
	 return :interconnect
      end
      assert_equal flash_message, "You are logged in now"
      assert_equal flash_message_type, :info
      validate_page
      return :success
    else
      assert_equal flash_message, "Authentication failed"
      assert_equal flash_message_type, :alert 
      
      $page = LoginPage.new_ready @driver
    end
  end
  
  # checks if the admin ended on the interconnect setup page
  def is_interconnect_page?
    x = @driver.find_element :xpath =>
            "//div[@id='content']/div/h2"
    return x.text == "Connect a remote Open Build Service instance"
  end
  
  # ============================================================================
  # logs in the user unless he's already in. Useful for tests to make sure the 
  # correct user is logged in - :depends on works if it's working one by one in line
  def verify_login user
    cu = current_user
    if cu != user
      unless cu == :none
        logout
        if @driver.current_url != @url
          @driver.get @url
        end
      end
      if user != :none
        login_as user
      end
      if @driver.current_url != @url
         @driver.get @url
      end
    end
  end

  # ============================================================================
  # Logs out the current user. In case of MainPage updates
  # current object and validates state of the displayed page.
  # @note In any other case spawns new MainPage without logged user.
  #
  def logout
    @driver[:xpath => 
      "//div[@id='subheader']//a[@href='/user/logout']"].click
    validate { not user_is_logged? }
    
    if self.class == MainPage then
      @user = :none
      validate_page
    else
      $page = MainPage.new_ready @driver
    end
  end
  
  # verifies the correct user is logged in
  def navigate_to page, options={}
     if options[:user]
       verify_login options[:user]
     end
     super
  end

  
  # ============================================================================
  # Checks if the user has new requests
  #
  def user_has_new_requests?
    results = @driver.find_elements :xpath => 
      "//div[@id='subheader']//a[@href='/home/my_work']"
    not results.empty?
  end
  
  
  # ============================================================================
  # Checks if a flash message is displayed on screen
  #
  def flash_message_appeared?
    flash_message_type != nil
  end


  # ============================================================================
  # Returns the text of the flash message currenlty on screen
  # @note Doesn't fail if no message is on screen. Returns empty string instead.
  # @return [String]
  #
  def flash_message
    results = @driver.find_elements :xpath => "//div[@id='flash-messages']//span"
    if results.empty?
      return ""
    end
    raise "One flash expected, but we had more." if results.count != 1
    return results.first.text
  end
  
  # ============================================================================
  # Returns the text of the flash messages currenlty on screen
  # @note Doesn't fail if no message is on screen. Returns empty list instead.
  # @return [array]
  #
  def flash_messages
    results = @driver.find_elements :xpath => "//div[@id='flash-messages']//span"
    ret = []
    results.each { |r| ret << r.text }
    return ret
  end
 
  # ============================================================================
  # Returns the type of the flash message currenlty on screen
  # @note Does not fail if no message is on screen! Returns nil instead!
  # @return [:info, :alert]
  #
  def flash_message_type
    results = @driver.find_elements :xpath => "//div[@id='flash-messages']//span"
    return nil if results.empty?
    return :info  if results.first.attribute("class").include? "info"
    return :alert if results.first.attribute("class").include? "alert" 
  end
  
  
  # ============================================================================
  # Gets the currently logged user.
  # @note The method expects that the current user exist as an entry in $data.
  # @return [Hash, :none] the credentials of the current user or :none.
  #
  def current_user
    return :none unless user_is_logged?
    username = @driver[:xpath => "//div[@id='subheader']//a[@href='/home']"].text
    matched_users = Array.new
    $data.each_value { 
      |user| matched_users << user if Hash === user and user[:login] == username }
    assert matched_users.size == 1
    matched_users.first
  end
  
  
  # ============================================================================
  # Checks if a user is logged
  #
  def user_is_logged?
    x = @driver.find_elements :xpath => 
      "//div[@id='subheader']/div/a[@href='/user/logout']"
    not x.empty?
  end
  
  
  # ============================================================================
  # Opens home project link in the header of any OBS page.
  # @note Checks if home project doesn't exist yet and spawns 
  #   a NewProjectPage. In any other case leads to ProjectOverviewPage.
  #
  def open_home_project
    @driver[:xpath => 
      "//div[@id='subheader']//a[starts-with(@*,'/project/show?project=home')]"].click
    sleep 2
    
    if flash_message.include? "Your home project doesn't exist yet"
      $page = NewProjectPage.new_ready @driver
    else
      $page = ProjectOverviewPage.new_ready @driver
    end
  end
  
  
  # ============================================================================
  # Opens user's home profile from the link in the header.
  #
  def open_home
    @driver[:xpath => 
      "//div[@id='subheader']//a[@href='/home']"].click
    $page = UserHomePage.new_ready @driver
  end
  
  
  # ============================================================================
  # Opens the Status Monitor page from the link in the footer.
  #
  def open_status_monitor
    @driver[:xpath => 
      "//div[@id='footer']//a[@href='/monitor']"].click
    $page=StatusMonitorPage.new_ready @driver
  end
  
  
  # ============================================================================
  # Opens the Search page from the link in the footer.
  #
  def open_search
    @driver[:xpath => 
      "//div[@id='footer']//a[@href='/search']"].click
    $page=SearchPage.new_ready @driver
  end
  
  
  # ============================================================================
  # Opens All Projects page from the link in the footer.
  #
  def open_all_projects
    @driver[:xpath => 
      "//div[@id='footer']//a[@href='/project/list_public']"].click
    $page=AllProjectsPage.new_ready @driver
  end
  
  
  # ============================================================================
  # Opens user's projects page from the link in the footer.
  #
  def open_my_projects
    @driver[:xpath => 
      "//div[@id='footer']//a[@href='/home/list_my']"].click
    $page=MyProjectsPage.new_ready @driver
  end
  
  
  # ============================================================================
  # Opens user's work page from the link in the footer.
  #
  def open_my_work
    @driver[:xpath => 
      "//div[@id='footer']//a[@href='/home/my_work']"].click
    $page = MyWorkPage.new_ready @driver
  end

  def page_source
    @driver.page_source
  end

  def wait_for_javascript
    wait.until {
      @driver.execute_script('return jQuery.active') == 0
    }
  end

  def wait_for_page
    res = nil
    wait.until {
      res = @driver.find_elements(:xpath => '//a[@href="/"]')
    }
    res
  end

end
