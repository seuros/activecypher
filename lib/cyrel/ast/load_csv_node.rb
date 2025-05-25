# frozen_string_literal: true

module Cyrel
  module AST
    # AST node for LOAD CSV clause (extension)
    # For when you need to import data from the ancient format of CSV
    class LoadCsvNode < ClauseNode
      attr_reader :url, :variable, :with_headers, :fieldterminator

      def initialize(url, variable, with_headers: false, fieldterminator: nil)
        @url = url
        @variable = variable
        @with_headers = with_headers
        @fieldterminator = fieldterminator
      end

      protected

      def state
        [@url, @variable, @with_headers, @fieldterminator]
      end
    end
  end
end
