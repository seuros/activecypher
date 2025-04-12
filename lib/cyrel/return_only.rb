# frozen_string_literal: true

module Cyrel
  # Class for standalone RETURN statements
  class ReturnOnly
    def initialize(return_values)
      @return_values = return_values
    end

    def to_cypher
      formatted_values = @return_values.map do |alias_name, value|
        formatted = case value
                    when Array
                      "[#{value.join(', ')}]"
                    when Hash
                      "{#{value.map { |k, v| "#{k}: #{v.is_a?(String) ? "\"#{v}\"" : v}" }.join(', ')}}"
                    else
                      value.to_s
                    end
        "#{formatted} AS #{alias_name}"
      end

      "RETURN #{formatted_values.join(', ')}"
    end
  end
end
