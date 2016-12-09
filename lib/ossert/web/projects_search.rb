module Ossert
  module Web
    module ProjectsSearch
      module_function

      def by_name(name)
        Results.new(name)
      end

      class Results
        LIMIT = 15
        SUGGESTIONS_SEARCH_URL = 'https://rubygems.org/api/v1/search.json'

        attr_reader :suggestions_results, :local_results

        def initialize(project_name)
          @project_name = project_name

          @suggestions_results = fetch_suggestions_results
          @local_results = fetch_local_results(
            project_names(suggestions_results)
          )
        end

        def found_any?
          local_results.any? || suggestions_results.any?
        end

        def exact_match_found?
          local_exact_match || suggestion_exact_match
        end

        def local_matches
          project_names(local_results) - [local_exact_match]
        end

        def suggestions
          project_names(suggestions_results) - project_names(local_results)
        end

        def local_exact_match
          (find_local_match || {})[:name]
        end

        def suggestion_exact_match
          (find_suggestions_match || {})[:name]
        end

        private

        def fetch_local_results(included_projects)
          ::Project
            .where('name % ?', @project_name)
            .or(name: included_projects)
            .select(
              Sequel.lit('name'),
              Sequel.lit("name <-> #{::Project.db.literal(@project_name)} AS distance"))
            .order(:distance)
            .limit(LIMIT)
            .to_a
        end

        def fetch_suggestions_results
          response = Faraday.new
            .get(SUGGESTIONS_SEARCH_URL, query: @project_name)

          if response.status == 200
            JSON.parse(response.body, symbolize_names: true).take(LIMIT)
          else
            # TODO: log error
            []
          end
        rescue Faraday::Error
          # TODO: log error
          []
        end

        def find_local_match
          local_results.find do |project|
            project[:distance].zero?
          end
        end

        def find_suggestions_match
          suggestions_results.find do |project|
            project[:name] == @project_name.downcase
          end
        end

        def project_names(projects)
          projects.map { |project| project[:name] }
        end
      end
    end
  end
end
