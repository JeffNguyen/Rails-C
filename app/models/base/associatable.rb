require 'active_support/inflector'
require_relative 'db_connection'

class AssocOptions
  attr_accessor :foreign_key, :class_name, :primary_key

  def model_class
    class_name.to_s.constantize
  end

  def table_name
    model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    defaults = {
      class_name: name.to_s.camelcase,
      primary_key: :id,
      foreign_key: "#{name}_id".to_sym
    }

    params = defaults.merge(options)

    params.each do |param, value|
      instance_variable_set("@#{param}", value)
    end
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    defaults = {
      class_name: name.to_s.singularize.camelcase,
      primary_key: :id,
      foreign_key: "#{self_class_name.to_s.downcase}_id".to_sym
    }

    params = defaults.merge(options)

    params.each do |param, value|
      instance_variable_set("@#{param}", value)
    end
  end
end

module Associatable
  def belongs_to(name, options = {})
    if options[:through]
      belongs_to_through(name, options[:through], options[:source])
      return
    end

    associated_opts = BelongsToOptions.new(name, options)
    define_method(name) do
      fk = self.send(associated_opts.foreign_key)
      #find is an ActiveRecord::Base method
      associated_opts.model_class.find(fk)
    end
    assoc_options[name] = associated_opts
  end

  def has_many(name, options = {})
    if options[:through]
      has_many_through(name, options[:through], options[:source])
      return
    end

    associated_opts = HasManyOptions.new(name, self, options)
    define_method(name) do
      associated_opts.model_class.where(
                {associated_opts.foreign_key => self.id}
      )
    end
    assoc_options[name] = associated_opts
  end

  def assoc_options
    @options ||= {}
    @options
  end

  #should call this if through is passed in as an option to has_one
  def has_one_through(name, through_name, source_name)
    through_options = self.assoc_options[through_name]
    define_method(name) do
      source_options = through_options
        .model_class
        .assoc_options[source_name]

      t1 = self.class.table_name
      t2 = through_options.model_class.table_name
      t3 = source_options.model_class.table_name

      answer = DBConnection.execute(<<-SQL)
        SELECT
          #{t3}.*
        FROM
          #{t1}
        INNER JOIN
          #{t2} ON #{t2}.#{through_options.primary_key}=
            #{t1}.#{through_options.foreign_key}
        INNER JOIN
          #{t3} ON #{t3}.#{source_options.primary_key}=
            #{t2}.#{source_options.foreign_key}
        WHERE
          #{t1}.id = #{self.id}
      SQL

      source_options.model_class.new(answer.first)
    end
  end

  def has_many_through(name, through_name, source_name)
    source_name = name if source_name.nil?
    through_options = assoc_options[through_name]
    source_options = through_options.model_class.assoc_options[source_name]
    define_method(name) do
      t1 = self.class.table_name
      t2 = through_options.table_name
      t3 = source_options.table_name

      if through_options.is_a?(BelongsToOptions)
        #current obj belongs to another obj which has many somethings
        answer = DBConnection.execute(<<-SQL)
          SELECT
            #{t3}.*
          FROM
            #{t1}
          INNER JOIN
            #{t2} ON #{t2}.#{through_options.primary_key}=
              #{t1}.#{through_options.foreign_key}
          INNER JOIN
            #{t3} ON #{t3}.#{source_options.foreign_key}=
              #{t2}.#{source_options.primary_key}
          WHERE
            #{t1}.id = #{self.id}
        SQL
      elsif through_options.is_a?(HasManyOptions)
        if source_options.is_a?(HasManyOptions)
          #current obj has many something, each of which has many somethings
          answer = DBConnection.execute(<<-SQL)
            SELECT
              #{t3}.*
            FROM
              #{t1}
            INNER JOIN
              #{t2} ON #{t2}.#{through_options.foreign_key}=
                #{t1}.#{through_options.primary_key}
            INNER JOIN
              #{t3} ON #{t3}.#{source_options.foreign_key}=
                #{t2}.#{source_options.primary_key}
            WHERE
              #{t1}.id = #{self.id}
          SQL
        elsif source_options.is_a?(BelongsToOptions)
          #current obj has many somethings, each of which belongs to a thing
          answer = DBConnection.execute(<<-SQL)
            SELECT
              #{t3}.*
            FROM
              #{t1}
            INNER JOIN
              #{t2} ON #{t2}.#{through_options.foreign_key}=
                #{t1}.#{through_options.primary_key}
            INNER JOIN
              #{t3} ON #{t3}.#{source_options.primary_key}=
                #{t2}.#{source_options.foreign_key}
            WHERE
              #{t1}.id = #{self.id}
          SQL
        end
      end

      answer.map do |answer|
        source_options.model_class.new(answer)
      end
    end
  end

  def belongs_to_through(name, through_name, source_name)
    source_name = name if source_name.nil?
    through_options = assoc_options[through_name]
    source_options = through_options.model_class.assoc_options[source_name]
    define_method(name) do
      t1 = self.class.table_name
      t2 = through_options.table_name
      t3 = source_options.table_name

      answer = DBConnection.execute(<<-SQL)
        SELECT
          #{t3}.*
        FROM
          #{t1}
        INNER JOIN
          #{t2} ON #{t2}.#{through_options.primary_key}=
            #{t1}.#{through_options.foreign_key}
        INNER JOIN
          #{t3} ON #{t3}.#{source_options.primary_key}=
            #{t2}.#{source_options.foreign_key}
        WHERE
          #{t1}.id = #{self.id}
      SQL

      source_options.model_class.new(answer.first)
    end
  end
end
