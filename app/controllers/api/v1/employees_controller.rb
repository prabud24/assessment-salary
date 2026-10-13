module Api
  module V1
    class EmployeesController < ApplicationController
      EMPLOYEE_FIELDS = %i[
        id employee_number name email country_code department status created_at updated_at
      ].freeze
      PERMITTED_EMPLOYEE_FIELDS = %i[
        employee_number name email country_code department status
      ].freeze
      DEFAULT_PAGE = 1
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      def index
        page, error = pagination_value(:page, default: DEFAULT_PAGE)
        return render_pagination_error(:page, error) if error

        per_page, error = pagination_value(:per_page, default: DEFAULT_PER_PAGE, maximum: MAX_PER_PAGE)
        return render_pagination_error(:per_page, error) if error

        employees = filtered_employees
        total_count = employees.count
        results = employees.order(:employee_number)
          .offset((page - 1) * per_page)
          .limit(per_page)

        render json: {
          employees: results.map { |employee| employee_json(employee) },
          pagination: {
            page:,
            per_page:,
            total_count:,
            total_pages: (total_count + per_page - 1) / per_page
          }
        }, status: :ok
      end

      def create
        employee = Employee.new(employee_params)

        if employee.save
          render json: { employee: employee_json(employee) },
            status: :created,
            location: api_v1_employee_url(employee)
        else
          render_validation_errors(employee)
        end
      end

      def show
        render json: { employee: employee_json(Employee.find(params[:id])) }, status: :ok
      end

      def update
        employee = Employee.find(params[:id])

        if employee.update(employee_params)
          render json: { employee: employee_json(employee) }, status: :ok
        else
          render_validation_errors(employee)
        end
      end

      private

      def filtered_employees
        employees = Employee.all

        if params[:q].present?
          search = "%#{Employee.sanitize_sql_like(params[:q].to_s)}%"
          employees = employees.where(
            "employee_number ILIKE :search OR name ILIKE :search OR email ILIKE :search",
            search:
          )
        end

        employees = employees.where(country_code: params[:country]) if params[:country].present?
        employees = employees.where(department: params[:department]) if params[:department].present?
        employees = employees.where(status: params[:status]) if params[:status].present?

        employees
      end

      def pagination_value(name, default:, maximum: nil)
        return [ default, nil ] unless params.key?(name)

        raw_value = params[name]
        return [ nil, "must be a positive integer" ] unless raw_value.is_a?(String) && raw_value.match?(/\A[0-9]+\z/)

        value = Integer(raw_value, 10)
        return [ nil, "must be a positive integer" ] unless value.positive?

        [ maximum ? [ value, maximum ].min : value, nil ]
      end

      def employee_params
        params.require(:employee).permit(*PERMITTED_EMPLOYEE_FIELDS)
      end

      def employee_json(employee)
        employee.as_json(only: EMPLOYEE_FIELDS)
      end

      def render_validation_errors(employee)
        render json: { errors: employee.errors.to_hash }, status: :unprocessable_entity
      end

      def render_pagination_error(field, message)
        render json: { errors: { field => [ message ] } }, status: :bad_request
      end

      def render_not_found
        render json: { errors: { base: [ "Employee not found" ] } }, status: :not_found
      end
    end
  end
end
