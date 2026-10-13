module Api
  module V1
    class InsightsController < ApplicationController
      def average_salary_by_country
        render json: {
          results: SalaryInsights.average_salary_by_country(
            business_date: SalaryInsights.current_business_date
          )
        }, status: :ok
      end

      def total_salary_by_department
        render json: {
          results: SalaryInsights.total_salary_by_department(
            business_date: SalaryInsights.current_business_date
          )
        }, status: :ok
      end

      def salary_increases
        start_date, start_error = parse_date(:start)
        end_date, end_error = parse_date(:end)
        errors = {}
        errors[:start] = [ start_error ] if start_error
        errors[:end] = [ end_error ] if end_error

        if errors.empty? && start_date >= end_date
          errors[:end] = [ "must be after start" ]
        end

        return render json: { errors: }, status: :unprocessable_entity if errors.any?

        render json: {
          results: SalaryInsights.salary_increases(start_date:, end_date:)
        }, status: :ok
      end

      private

      def parse_date(field)
        value = params[field]
        return [ nil, "is required" ] if value.blank?
        return [ nil, "must be a valid date in YYYY-MM-DD format" ] unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        [ Date.iso8601(value), nil ]
      rescue Date::Error
        [ nil, "must be a valid date in YYYY-MM-DD format" ]
      end
    end
  end
end
