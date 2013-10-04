Feature: Project Settings
  Background:
    Given there are the following project types:
      | Name         | Allows Association |
      | Copy Project | true               |
    And there are the following projects of type "Copy Project":
      | project1 |
    And there is 1 user with the following:
      | login     | bob        |
      | firstname | Bob        |
      | Lastname  | Bobbit     |
    And there is 1 user with the following:
      | login     | alice      |
      | firstname | Alice      |
      | Lastname  | Alison     |
    And there is a role "alpha"
    And there is a role "beta"
    And the role "alpha" may have the following rights:
      | copy_projects |
      | edit_project  |
    And the role "beta" may have the following rights:
      | edit_project  |
    And the user "alice" is a "alpha" in the project "project1"
    And the user "bob" is a "beta" in the project "project1"

  Scenario: Check for the existence of a copy button
    When I am already admin
    And  I go to the settings page of the project "project1"
    Then I should see "Copy" within "#content"

  Scenario: Permission test for copy button with authorized role
    When I am already logged in as "alice"
    And  I go to the settings page of the project "project1"
    Then I should see "Copy" within "#content"

  Scenario: Permission test for copy button without authorized role
    When I am already logged in as "bob"
    And  I go to the members tab of the settings page of the project "project1"
    Then I should not see "Copy" within "#content"

  Scenario: Check for differences in admin's and settings' copy
    When I am already admin
    And  I go to the admin page
    And  I follow "Projects" within "#main-menu"
    #just one project, so we should be fine
    And  I click on "Copy" within "#content"
    Then I should see "Modules" within "#content"
    When I go to the settings page of the project "project1"
    And  I follow "Copy" within "#content"
    Then I should not see "Modules" within "#content"

  Scenario: Check for presence and default status of the copying parameters
    When I am already admin
    When I go to the settings page of the project "project1"
    And  I follow "Copy" within "#content"
    Then I should see "Custom queries" within "#content"
    And  the "Custom queries" checkbox should be checked within "#content"
    And  I should see "Forums" within "#content"
    And  the "Forums" checkbox should not be checked within "#content"
    And  I should see "Members" within "#content"
    And  the "Members" checkbox should be checked within "#content"
    And  I should see "Reportings" within "#content"
    And  the "Reportings" checkbox should be checked within "#content"
    And  I should see "Timeline reports" within "#content"
    And  the "Timeline reports" checkbox should be checked within "#content"
    And  I should see "Versions" within "#content"
    And  the "Versions" checkbox should be checked within "#content"
    And  I should see "Wiki" within "#content"
    And  the "Wiki" checkbox should be checked within "#content"
    And  I should see "Work packages" within "#content"
    And  the "Work packages" checkbox should not be checked within "#content"
    And  I should see "Work package categories" within "#content"
    And  the "Work package categories" checkbox should be checked within "#content"

  Scenario: Check for presence and default status of the copying parameters
    When I am already admin
    When I go to the settings page of the project "project1"
    And  I follow "Copy" within "#content"
    Then the "Identifier" field should not contain "project1" within "#content"
    And  the "Name" field should not contain "project1" within "#content"

  @javascript
  Scenario: Copy a project with some queries
    When I am already admin
    And  the project "project1" has 10 work package queries with the following:
      | is_public | true |
    When I go to the settings page of the project "project1"
    And  I follow "Copy" within "#content"
    And  I fill in "Name" with "Copied Project"
    And  I fill in "Identifier" with "cp"
    And  I click on "Copy"
    Then I should see "Successful creation."
    When I go to the work package index page for the project "Copied Project"
    Then I should see "Query 1" within "#sidebar"
    Then I should see "Query 2" within "#sidebar"
    Then I should see "Query 3" within "#sidebar"
    Then I should see "Query 4" within "#sidebar"
    Then I should see "Query 5" within "#sidebar"
    Then I should see "Query 6" within "#sidebar"
    Then I should see "Query 7" within "#sidebar"
    Then I should see "Query 8" within "#sidebar"
    Then I should see "Query 9" within "#sidebar"
    Then I should see "Query 10" within "#sidebar"

  @javascript
  Scenario: Copy a project with some members (Users)
    When I am already admin
    And  I go to the settings page of the project "project1"
    And  I follow "Copy" within "#content"
    And  I fill in "Name" with "Copied Project"
    And  I click on "Copy"
    Then I should see "Successful creation."
    When I go to the members tab of the settings page of the project "copied-project"
    Then I should see the principal "Alice Alison" as a member with the roles:
      | alpha |
    And I should see the principal "Bob Bobbit" as a member with the roles:
      | beta |

  @javascript
  Scenario: Copy a project with some members (Groups)
    Given there is 1 group with the following:
      | name | group1 |
    And there is 1 group with the following:
      | name | group2 |
    And the group "group1" is a "alpha" in the project "project1"
    And the group "group2" is a "alpha" in the project "project1"
    When I am already admin
    And  I go to the settings page of the project "project1"
    And  I follow "Copy" within "#content"
    And  I fill in "Name" with "Copied Project"
    And  I click on "Copy"
    Then I should see "Successful creation."
    When I go to the members tab of the settings page of the project "copied-project"
    Then I should see the principal "group1" as a member with the roles:
      | alpha |
    Then I should see the principal "group2" as a member with the roles:
      | alpha |

  @javascript
  Scenario: Copy a project with some boards
    When I am already admin
    And  there is a board "Board 1" for project "project1"
    And  there is a board "Board 2" for project "project1"
    When I go to the settings page of the project "project1"
    And  I follow "Copy" within "#content"
    And  I fill in "Name" with "Copied Project"
    And  I fill in "Identifier" with "cp"
    And  I check "Forums"
    And  I click on "Copy"
    Then I should see "Successful creation."
    And  I go to the overview page for the project "Copied Project"
    And  I follow "Forums" within "#main-menu"
    Then I should see "Board 1" within "#content"
    Then I should see "Board 2" within "#content"

  @javascript
  Scenario: Copy a project with project_a_associations
    Given there are the following projects of type "Copy Project":
      | project2 |
    And there are the following project associations:
      | Project A | Project B |
      | project1  | project2  |
    When I am already admin
    And  I go to the settings page of the project "project1"
    And  I follow "Copy" within "#content"
    And  I fill in "Name" with "Copied Project"
    And  I fill in "Identifier" with "cp"
    And  I check "Reportings"
    And  I click on "Copy"
    Then I should see "Successful creation."
    And  I go to the overview page for the project "Copied Project"
    And  I toggle the "Timelines" submenu
    And  I follow "Dependencies"
    Then I should see "project2" within "#content"

  @javascript
  Scenario: Copy a project with project_b_associations
    Given there are the following projects of type "Copy Project":
      | project2 |
    And there are the following project associations:
      | Project A | Project B |
      | project2  | project1  |
    When I am already admin
    And  I go to the settings page of the project "project1"
    And  I follow "Copy" within "#content"
    And  I fill in "Name" with "Copied Project"
    And  I fill in "Identifier" with "cp"
    And  I check "Reportings"
    And  I click on "Copy"
    Then I should see "Successful creation."
    And  I go to the overview page for the project "Copied Project"
    And  I toggle the "Timelines" submenu
    And  I follow "Dependencies"
    Then I should see "project2" within "#content"

  @javascript
  Scenario: Copy a project with versions
    Given the project "project1" has 1 version with:
      | name           | version1   |
      | description    | yeah, boy  |
      | start_date     | 2001-08-02 |
      | effective_date | 2002-08-02 |
      | status         | closed     |
    When I am already admin
    And  I go to the settings page of the project "project1"
    And  I follow "Copy" within "#content"
    And  I fill in "Name" with "Copied Project"
    And  I fill in "Identifier" with "cp"
    And  I check "Versions"
    And  I click on "Copy"
    Then I should see "Successful creation."
    And  I go to the versions tab of the settings page for the project "cp"
    Then I should see "version1" within "#content"
    And  I should see "yeah, boy" within "#content"
    And  I should see "08/02/2001" within "#content"
    And  I should see "08/02/2002" within "#content"
    And  I should see "closed" within "#content"
