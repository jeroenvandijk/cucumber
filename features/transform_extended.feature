Feature: transform
  In order to maintain modularity within step definitions
  As a step definition editor
  I want to register a regex to capture and tranform step definition arguments with tupils.

    Background:
      Given a standard Cucumber project directory structure
      
    Scenario: apply a simple transform when a string and a table are matched
      Given a file named "features/step_definitions/steps.rb" with:
        """
        Then /^I have some (.+)$/ do |objects_name, objects_table|
          objects_name.should == "integers"
          objects_table.hashes.first.each { |k, v| v.should be_kind_of(Integer)}
        end
      
        Transform /^objects table:a,c$/ do |table|
          # this should not match
          table
        end
      
        Transform /^objects table:a,b$/ do |table|
          table.map_column!('a') { |column| column.to_i }
          table.map_column!('b') { |column| column.to_i }
          ["integers", table]
        end
        """
      And a file named "features/transform_sample.feature" with:
        """
        Feature: Step argument transformations
      
          Scenario: transform with String and table
            Then I have some objects
              | a | b |
              | 1 | 2 |
            
        """
      When I run cucumber -s --backtrace features
      Then it should pass with
        """
        Feature: Step argument transformations
      
          Scenario: transform with String and table
            Then I have some objects
              | a | b |
              | 1 | 2 |
      
        1 scenario (1 passed)
        1 step (1 passed)
      
        """
    
    Scenario: raise an error when a transform does not return two values
      Given a file named "features/step_definitions/steps.rb" with:
        """
        raise "test"
        Then /^somef (.+)$/ do |objects, table|
          raise "test"
          table
        end
          
        Transform /^objects table:.*$/ do |table|
          raise "test"
          ["objects", table]
        end
        """
      And a file named "features/transform_sample.feature" with:
        """
        Feature: Tupil transformations that do not return a tupil should fail
        
          Scenario: transform with String and table
            Given somef objects
              | a | b |
              | 1 | 2 |
      
        """
        
      Then it should pass with
        """
        Feature: Complex step argument transformations
        
          Scenario: transform with String and table
            Given some objects
                   | a | b |
      
        1 scenario (1 failed)
        1 step (1 failed) 
        """

    Scenario: apply a more complex transform when the string and table are matched
      Given a file named "features/step_definitions/steps.rb" with:
        """
        Given /^I have a "([^\"]*)" table with some (.+)$/ do |type, objects_name, table|
          @table = table
          @type = type
        end
        
        Transform /^objects table:.*$/ do |table|
          ["objects", table.transpose]
        end
        
        Then /^after transform I should have$/ do |table|
          @table.diff!(table)
        end
        
        Then /^after transform I should still have a "([^\"]*)" table$/ do |type|
          type.should == @type
        end
        
        """
      And a file named "features/transform_sample.feature" with:
        """
        Feature: Complex step argument transformations
        
          Scenario: transform with String and table
            Given I have a "strange" table with some objects
              | a | 1 |
              | b | 2 |
              | c | 3 |
            Then after transform I should have
              | a | b | c |
              | 1 | 2 | 3 |
            And after transform I should still have a "strange" table
        
        """
      When I run cucumber -s --backtrace features
      Then it should pass with
        """
        Feature: Complex step argument transformations
      
          Scenario: transform with String and table
            Given I have a "strange" table with some objects
              | a | 1 |
              | b | 2 |
              | c | 3 |
            Then after transform I should have
              | a | b | c |
              | 1 | 2 | 3 |
            And after transform I should still have a "strange" table

        1 scenario (1 passed)
        3 steps (3 passed)

        """
