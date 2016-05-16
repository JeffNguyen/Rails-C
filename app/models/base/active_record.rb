require_relative 'relation'
require_relative 'db_connection'
require_relative 'associatable'
require_relative 'errors'
require_relative 'record_invalid'
require './app/global/global'

class ActiveRecord
  class Base
    extend Associatable

    def self.all
      Relation.new(self)
    end

    def self.my_attr_accessor(*names)
      names.each do |name|
        define_method(name) do
          instance_variable_get("@#{name}")
        end
        define_method("#{name}=") do |value|
          instance_variable_set("@#{name}", value)
        end
      end
    end

    def self.table_name=(table_name)
      @table_name = table_name
    end

    def self.table_name
      @table_name ||= self.to_s.tableize
      @table_name = "humans" if self.to_s == "Human"
      @table_name
    end

    def self.columns
      @col_names ||= DBConnection.execute2(<<-SQL).first
        SELECT
          *
        FROM
          #{table_name}
      SQL

      @col_names.map(&:to_sym)
    end

    def self.finalize!
      #define getters
      columns.each do |col_name|
        define_method(col_name) do
          attributes[col_name]
        end

        #define setteres
        define_method("#{col_name}=") do |value|
          attributes[col_name] = value
        end
      end
    end

    def self.find(id)
      id = id.to_i
      result = DBConnection.execute(<<-SQL, id)
        SELECT
          *
        FROM
          #{table_name}
        WHERE
          id = ?
      SQL

      return nil if result.empty?
      self.new(result.first)
    end

    def self.first
      all.first
    end

    def self.includes(association)
      Relation.new(self).includes(association)
    end

    def self.last
      all.last
    end

    def self.validate(method)
      validation_methods << method
    end

    def self.validates(*attrs, validations)
      attrs.each do |attr|
        if validations[:presence]
          self.validate("#{attr}_must_be_present".to_sym)
        elsif validations[:uniqueness]
          self.validate("#{attr}_must_be_unique".to_sym)
        end
      end
    end

    def self.validation_methods
      @validation_methods ||= []
    end

    #maybe extract includes/where/all into a method missing?
    def self.where(params)
      Relation.new(self).where(params)
    end

    attr_accessor :errors

    def initialize(params = {})
      params.each do |attr_name, value|
        unless self.class.columns.include?(attr_name.to_sym)
          raise "unknown attribute '#{attr_name}'"
        end 
        self.send("#{attr_name}=".to_sym, value)
      end

      @errors = Errors.new(self.class)
    end

    def attributes
      @attributes ||= {}
      @attributes
    end

    def attribute_values
      attributes.values
    end

    def destroy
      DBConnection.execute(<<-SQL)
        DELETE FROM
          #{self.class.table_name}
        WHERE
          id=#{id}
      SQL
    end

    def insert
      attr_string = present_attrs.keys.join(", ")
      question_marks = Array.new(present_attrs.count, '?').join(", ")
      DBConnection.execute(<<-SQL, *(present_attrs.values))
        INSERT INTO
          #{self.class.table_name} (#{attr_string})
        VALUES
          (#{question_marks})
      SQL

      self.id = DBConnection.last_insert_row_id
    end

    def present_attrs
      attributes.reject { |k,v| v.nil? }
    end

    def save
      validate
      return false if errors.any?
      id.nil? ? insert : update_attrs
      true
    end

    def save!
      validate
      raise RecordInvalid if errors.any?
      id.nil? ? insert : update_attrs
    end

    def update(new_attrs)
      attributes.merge!(new_attrs)
      save
    end

    def update!(new_attrs)
      attributes.merge!(new_attrs)
      save!
    end

    def update_attrs
      set_string = present_attrs.map do |attr, _|
        "#{attr} = ?"
      end.join(", ")

      DBConnection.execute(<<-SQL, *(present_attrs.values))
      UPDATE
        #{self.class.table_name}
      SET
        #{set_string}
      WHERE
        id = #{id}
      SQL
    end

    def validate
      self.class.validation_methods.each { |method| send(method) }
    end

    private

    def method_missing(method, *args, &prc)
      presence_match = method.to_s.match(/^(?<attr>.+)\_must\_be\_present$/)
      uniqueness_match = method.to_s.match(/^(?<attr>.+)\_must\_be\_unique$/)

      if presence_match
        must_be_present(presence_match["attr"])
      elsif uniqueness_match
        must_be_unique(uniqueness_match["attr"])
      else
        super
      end
    end

    def must_be_present(attr)
      if send(attr.to_sym).nil?
        errors[attr] << "must be present."
      end
    end

    def must_be_unique(attr)
      self.class.all.each do |obj|
        if send(attr) == obj.send(attr) && id != obj.id
          errors[attr] << "must be unique"
        end
      end
    end
  end
end
