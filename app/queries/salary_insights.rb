class SalaryInsights
  BUSINESS_TIME_ZONE = "Asia/Kolkata"

  def self.average_salary_by_country(business_date:)
    current_salaries(business_date:)
      .group("employees.country_code", "salary_records.currency")
      .order("employees.country_code", "salary_records.currency")
      .pluck(
        Arel.sql("employees.country_code"),
        Arel.sql("salary_records.currency"),
        Arel.sql("AVG(salary_records.annual_salary)"),
        Arel.sql("COUNT(DISTINCT employees.id)")
      ).map do |country, currency, average_salary, employee_count|
        {
          country:,
          currency:,
          average_salary: average_salary.to_s("F"),
          employee_count:
        }
      end
  end

  def self.total_salary_by_department(business_date:)
    current_salaries(business_date:)
      .group("employees.department", "salary_records.currency")
      .order("employees.department", "salary_records.currency")
      .pluck(
        Arel.sql("employees.department"),
        Arel.sql("salary_records.currency"),
        Arel.sql("SUM(salary_records.annual_salary)"),
        Arel.sql("COUNT(DISTINCT employees.id)")
      ).map do |department, currency, total_salary, employee_count|
        {
          department:,
          currency:,
          total_salary: total_salary.to_s("F"),
          employee_count:
        }
      end
  end

  def self.salary_increases(start_date:, end_date:)
    sql = SalaryRecord.sanitize_sql_array(
      [
        <<~SQL,
          WITH salary_history AS (
            SELECT
              employee_id,
              currency,
              annual_salary,
              effective_from,
              LAG(currency) OVER history AS previous_currency,
              LAG(annual_salary) OVER history AS previous_annual_salary
            FROM salary_records
            WINDOW history AS (PARTITION BY employee_id ORDER BY effective_from, id)
          )
          SELECT currency, COUNT(*) AS increase_count
          FROM salary_history
          WHERE effective_from >= ? AND effective_from < ?
            AND currency = previous_currency
            AND annual_salary > previous_annual_salary
          GROUP BY currency
          ORDER BY currency
        SQL
        start_date,
        end_date
      ]
    )

    SalaryRecord.connection.select_all(sql).map do |row|
      { currency: row["currency"], increase_count: row["increase_count"].to_i }
    end
  end

  def self.current_business_date
    Time.current.in_time_zone(BUSINESS_TIME_ZONE).to_date
  end

  def self.current_salaries(business_date:)
    SalaryRecord.joins(:employee)
      .where(employees: { status: "active" })
      .where("salary_records.effective_from <= ?", business_date)
      .where("salary_records.effective_to IS NULL OR salary_records.effective_to > ?", business_date)
  end

  private_class_method :current_salaries
end
