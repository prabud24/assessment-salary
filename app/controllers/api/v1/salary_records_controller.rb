module Api
  module V1
    class SalaryRecordsController < ApplicationController
      SALARY_RECORD_FIELDS = %i[
        annual_salary currency effective_from effective_to created_at updated_at
      ].freeze
      PERMITTED_SALARY_RECORD_FIELDS = %i[annual_salary currency effective_from].freeze

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      def index
        employee = Employee.find(params[:employee_id])
        salary_records = SalaryRecord.where(employee_id: employee.id)
          .order(effective_from: :desc, id: :desc)

        render json: { salary_records: salary_records.map { |record| salary_record_json(record) } }, status: :ok
      end

      def create
        employee = Employee.find(params[:employee_id])
        attributes = salary_record_params
        effective_from, date_error = parse_effective_from(attributes[:effective_from])
        return render_validation_errors(effective_from: [ date_error ]) if date_error

        result = RecordSalaryChange.new(
          employee: employee,
          annual_salary: attributes[:annual_salary],
          currency: attributes[:currency],
          effective_from: effective_from,
          business_date: Time.current.in_time_zone("Asia/Kolkata").to_date
        ).call

        if result.success?
          render json: { salary_record: salary_record_json(result.salary_record) }, status: :created
        else
          render_validation_errors(result.errors)
        end
      end

      private

      def salary_record_params
        params.fetch(:salary_record, ActionController::Parameters.new)
          .permit(*PERMITTED_SALARY_RECORD_FIELDS)
      end

      def parse_effective_from(value)
        return [ nil, "is required" ] if value.blank?
        return [ nil, "must be a valid date in YYYY-MM-DD format" ] unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        [ Date.iso8601(value), nil ]
      rescue Date::Error
        [ nil, "must be a valid date in YYYY-MM-DD format" ]
      end

      def salary_record_json(salary_record)
        attributes = salary_record.as_json(only: SALARY_RECORD_FIELDS)
        attributes["annual_salary"] = salary_record.annual_salary.to_s("F")
        attributes
      end

      def render_validation_errors(errors)
        render json: { errors: }, status: :unprocessable_entity
      end

      def render_not_found
        render json: { errors: { base: [ "Employee not found" ] } }, status: :not_found
      end
    end
  end
end
