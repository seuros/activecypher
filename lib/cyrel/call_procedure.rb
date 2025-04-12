# frozen_string_literal: true

module Cyrel
  # Class for handling CALL procedures
  class CallProcedure
    def initialize(procedure)
      @procedure = procedure
      @yield_fields = []
      @return_fields = []
    end

    def yield(*fields)
      @yield_fields = fields
      self
    end

    def return(*fields)
      @return_fields = fields
      self
    end

    def to_cypher
      parts = ["CALL #{@procedure}()"]
      parts << "YIELD #{@yield_fields.join(', ')}" if @yield_fields.any?
      parts << "RETURN #{@return_fields.join(', ')}" if @return_fields.any?
      parts.join(' ')
    end
  end
end
