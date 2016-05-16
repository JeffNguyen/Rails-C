require_relative 'db_connection'
require 'active_support/inflector'

class Relation
  attr_reader :query_values

  def initialize(model_type)
    @query_values = {where: {}, includes: {}}
    @model_type = model_type
    @inhereting_table = model_type.table_name
  end

  def all
    self
  end

  def display
    executed_query.inspect
  end

  def includes(association)
    query_values[:includes][association] = true
    self
  end

  def reload!
    execute_query
  end

  def where(params)
    params.each do |param, value|
      query_values[:where][param] = value
    end

    self
  end

  private

  def extra_columns_string
    #have to specifiy columns in the query or else id column will be overwritten
    answer = ""
    query_values[:includes].each do |k, v|
      assoc_options = model_type.assoc_options[k]
      prefix = ", #{assoc_options.table_name}."

      non_id_cols = assoc_options.model_class.columns.dup
      non_id_cols.delete(:id)

      non_id_cols.each do |col|
        answer += "#{prefix}#{col}"
      end

      #maybe should alias all attributes to prevent other collisions
      answer += "#{prefix}id AS #{assoc_options.model_class.to_s.downcase}_id"
    end

    answer
  end

  def executed_query
    @executed_query || execute_query
  end

  def execute_query
     query_result = DBConnection.execute(<<-SQL, *query_values[:where].values)
      SELECT
        #{inhereting_table}.*#{extra_columns_string}
      FROM
        #{inhereting_table}
      #{join_string}
      WHERE
        #{where_line}
    SQL

    @executed_query = parse(query_result)
  end

  def extract_model_attrs(all_attrs, model_class, id_key)
    #no model to extract
    return if all_attrs[id_key.to_s].nil?

    new_obj = model_class.new
    model_class.columns.each do |col_name|
      new_obj.send("#{col_name}=".to_sym, all_attrs[col_name.to_s])
    end

    new_obj.id = all_attrs[id_key.to_s]
    new_obj
  end

  def join_string
    return "" if query_values[:includes].empty?

    query_values[:includes].keys.map do |assoc|
      assoc_options = model_type.assoc_options[assoc]

      if assoc_options.is_a?(BelongsToOptions)
        <<-SQL
          LEFT OUTER JOIN
            #{assoc_options.table_name}
          ON
            #{assoc_options.table_name}.#{assoc_options.primary_key} = #{inhereting_table}.#{assoc_options.foreign_key}
        SQL
      elsif assoc_options.is_a?(HasManyOptions)
        <<-SQL
          LEFT OUTER JOIN
            #{assoc_options.table_name}
          ON
          #{assoc_options.table_name}.#{assoc_options.foreign_key} = #{inhereting_table}.#{assoc_options.primary_key}
        SQL
      end
    end.join("\n")
  end

  def method_missing(method, *args, &prc)
    if [].methods.include?(method)
      executed_query.send(method, *args, &prc)
    else
      super
    end
  end

  def merge_sort(arr, qual)
    length = arr.length
    return arr if length <= 1
    left, right = arr[0..(length - 1) / 2], arr[(length - 1)/2 + 1...length]
    merge(merge_sort(left, qual), merge_sort(right, qual), qual)
  end

  def merge(arr1, arr2, qual)
    sorted_array = []
    until arr1.empty? || arr2.empty?
      if arr1.first[qual.to_s].nil?
        sorted_array.push(arr1.shift)
      elsif arr2.first[qual.to_s].nil?
        sorted_array.push(arr2.shift)
      elsif arr1.first[qual.to_s] > arr2.first[qual.to_s]
        sorted_array.push(arr2.shift)
      else
        sorted_array.push(arr1.shift)
      end
    end

    sorted_array + arr1 + arr2
  end

  def n_wise_stable_sort(arr, keys)
    ##TODO I don't actually need a SORT here, I just need the correct groupings -- can make linear time by just putting into pockets for each key
    working_arr = arr
    keys.reverse.each do |key|
      working_arr = merge_sort(working_arr, key)
    end

    working_arr = merge_sort(working_arr, :id)
  end

  def parse(query_result)
    sort_bys = query_values[:includes].keys.map do |assoc|
      model_type.assoc_options[assoc].foreign_key
    end

    #sorted_results will be an array of hashes sorted successively by each field in sort_bys. Sorting here so that can parse by iterating through only once
    sorted_results = n_wise_stable_sort(query_result, sort_bys)

    parsed_models = []

    #For each hash in the results array, first check if the id matches the last model in the parsed_models array (this is why we sorted). If it does, then this result is in the results because of an associated model, and we shoudl extract whatever was included accordingle. If it does not, then this is a new model, and we should extract its own qualities as well.
    sorted_results.each do |result|
      if parsed_models.last && parsed_models.last.id == result["id"]
        # already have this model accounted for. This step adds another model to its association
        working_model = parsed_models.pop #popping so can push later

        query_values[:includes].keys.each do |assoc|
          options = model_type.assoc_options[assoc]
          if options.is_a?(HasManyOptions)

            next_of_many_objs = extract_model_attrs(
                result,
                options.model_class,
                "#{options.model_class.to_s.downcase}_id"
            )

            #redefine association so that it includes the new model
            many_objs_so_far = working_model.send(assoc)
            unless next_of_many_objs.id == many_objs_so_far.last.id
              #only add to the array if it is not already there (another reason we sorted earlier)
              many_objs_so_far << next_of_many_objs
            end

            working_model.define_singleton_method(assoc) do
              many_objs_so_far
            end
          end
          #if the association is BelongsTo, then we have already taken care of it in a previous step
        end
      else
        # Model is new, so must extract attributes and add to parsed_models
        working_model = extract_model_attrs(
            result,
            model_type,
            "id"
        )

        query_values[:includes].keys.each do |assoc|
          options = model_type.assoc_options[assoc]

          if model_type.assoc_options[assoc].is_a?(BelongsToOptions)
            obj_belonged_to = extract_model_attrs(
                result,
                options.model_class,
                "#{options.model_class.to_s.downcase}_id"
                #explicitely aliased this earlier
            )
            working_model.define_singleton_method(assoc) do
              obj_belonged_to
            end
          elsif model_type.assoc_options[assoc].is_a?(HasManyOptions)
            first_of_many_objs = extract_model_attrs(
                result,
                options.model_class,
                "#{options.model_class.to_s.downcase}_id"
                #explicitely aliased this earlier
            )
            working_model.define_singleton_method(assoc) do
              first_of_many_objs ? [first_of_many_objs] : []
            end
          end
        end
      end

      parsed_models << working_model
    end

    parsed_models
  end

  def where_line
    query_values[:where].map do |col, _|
      "#{col} = ?"
    end.push("1=1").join(" AND ")
  end

  attr_reader :inhereting_table, :model_type
end
