module Sequel
  module Plugins
    # This plugin allows you to add filters on a per object basis that
    # restrict updating or deleting the object.  It's designed for cases
    # where you would normally have to drop down to the dataset level
    # to get the necessary control, because you only want to delete or
    # update the rows in certain cases based on the current status of
    # the row in the database.
    # 
    #   class Item < Sequel::Model
    #     plugin :instance_filters
    #   end
    #
    #   # These are two separate objects that represent the same
    #   # database row. 
    #   i1 = Item.first(:id=>1, :delete_allowed=>false)
    #   i2 = Item.first(:id=>1, :delete_allowed=>false)
    #
    #   # Add an instance filter to the object. This filter is in effect
    #   # until the object is successfully updated or deleted.
    #   i1.instance_filter(:delete_allowed=>true)
    #
    #   # Attempting to delete the object where the filter doesn't
    #   # match any rows raises an error.
    #   i1.delete # raises Sequel::Error
    #
    #   # The other object that represents the same row has no
    #   # instance filters, and can be updated normally.
    #   i2.update(:delete_allowed=>true)
    #
    #   # Even though the filter is now still in effect, since the
    #   # database row has been updated to allow deleting,
    #   # delete now works.
    #   i1.delete
    module InstanceFilters
      # Exception class raised when updating or deleting an object does
      # not affect exactly one row.
      class Error < Sequel::Error
      end

      module InstanceMethods
        # Clear the instance filters after successfully destroying the object.
        def after_destroy
          super
          clear_instance_filters
        end
        
        # Clear the instance filters after successfully updating the object.
        def after_update
          super
          clear_instance_filters
        end
      
        # Add an instance filter to the array of instance filters
        # Both the arguments given and the block are passed to the
        # dataset's filter method.
        def instance_filter(*args, &block)
          instance_filters << [args, block]
        end
      
        private
        
        # Lazily initialize the instance filter array.
        def instance_filters
          @instance_filters ||= []
        end
        
        # Apply the instance filters to the given dataset
        def apply_instance_filters(ds)
          instance_filters.inject(ds){|ds, i| ds.filter(*i[0], &i[1])}
        end
        
        # Clear the instance filters.
        def clear_instance_filters
          instance_filters.clear
        end
        
        # Apply the instance filters to the dataset returned by super.
        def _delete_dataset
          apply_instance_filters(super)
        end
        
        # Apply the instance filters to the dataset returned by super.
        def _update_dataset
          apply_instance_filters(super)
        end
        
        # Raise an Error if calling deleting doesn't
        # indicate that a single row was deleted.
        def _delete
          raise(Error, "No matching object for instance filtered dataset (SQL: #{_delete_dataset.delete_sql})") if super != 1
        end
        
        # Raise an Error if updating doesn't indicate that a single
        # row was updated.
        def _update(columns)
          raise(Error, "No matching object for instance filtered dataset (SQL: #{_update_dataset.update_sql(columns)})") if super != 1
        end
      end
    end
  end
end
