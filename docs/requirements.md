# Salary Management System — MVP Specification

## Goal and primary user

Build a web application that replaces spreadsheet-based salary management for an organization of 10,000 employees across multiple countries. It enables an authenticated HR Manager to find employees, manage salary history, and answer defined organizational salary questions. This is an assessment MVP, not a payroll system.

## MVP scope

### Employees

- Maintain employee number, name, email, country, department, and employment status (active or inactive).
- Employee number and email must be unique; email uniqueness is case-insensitive.
- Search by employee number, name, or email; filter by country, department, and employment status.
- Use stable, server-side pagination, ordered by employee number.
- Country and department are current employee attributes. Historical reports use current attributes; reporting past organizational assignments is out of scope.

### Salary history and changes

- Salary means **annual base salary**, excluding bonuses and benefits. Store a positive amount and a valid ISO 4217 currency code; do not convert currencies.
- Each salary record has an `effective_from` date (inclusive) and an `effective_to` date (exclusive). A null `effective_to` means no scheduled end. Periods for one employee must not overlap.
- Current salary as of the application date is the record for which `effective_from <= date` and (`effective_to` is null or `date < effective_to`). Future-dated records are not current before their start date. If no record matches, the employee has no current salary.
- An HR Manager may record a salary change effective today or in the future, strictly after the latest recorded `effective_from`; backdated changes, cancellations, and approval workflows are deferred. Recording a change sets the previous latest record’s `effective_to` to the new record’s `effective_from`, and the new latest record’s `effective_to` is null. This maintains adjacent, non-overlapping periods.
- Require all employee fields and salary fields. Reject duplicate employee numbers or emails, invalid currency codes, non-positive amounts, and salary amounts with more decimal places than the currency’s ISO 4217 minor-unit precision. Reject a salary change whose effective date is not later than the latest recorded start date.
- Record the acting HR Manager for each salary-record creation and each resulting change to a prior record’s end date.

### Insights

- Average current annual base salary by current country and currency.
- Total current annual base salary by current department and currency.
- Count employees with at least one comparable annual base salary increase effective during a selected date period, grouped by currency. The selected period is `[start, end)`. An increase is a record whose amount is greater than the immediately preceding record’s amount in the **same currency**; currency changes are not comparable and do not count as increases. Count each employee once per currency for the selected period, regardless of current employment status.
- Exclude inactive employees and employees without a current salary from the two current-salary summaries. Retain and display inactive employees’ salary history.

## Data, access, and assessment deliverables

- Seed exactly 10,000 employees with synthetic data, multiple currencies, and varied salary histories; do not use real employee data.
- Provide a minimal authenticated HR Manager access model. Complex role-based authorization and enterprise SSO are deferred.
- Deliver a working deployed application, automated tests for core business rules, and a demonstration.

## Out of scope and rationale

Defer spreadsheet import, payroll processing, taxes, benefits, attendance and leave, performance management, recruitment, employee self-service, payroll integrations, currency conversion, salary distribution charts, backdated corrections, cancellations, approval workflows, complex multi-level authorization, and enterprise SSO. These capabilities add separate workflows or domain rules beyond the focused goal of managing salary history and answering the defined insights; deferring them keeps the assessment achievable while demonstrating sound domain modelling, validation, and data handling.

## Non-functional requirements

- Support the 10,000-employee synthetic dataset with responsive core API operations.
- Use appropriate database indexes and avoid loading unneeded employee or salary-history data.
- Restrict salary data to authenticated HR Managers.
- Provide clear validation and error messages; exercise salary-period and increase rules with automated tests.
- Provide a usable responsive web interface and deployment instructions.

## Acceptance criteria

1. The seeded dataset contains 10,000 synthetic employees with varied salary histories and currencies.
2. An authenticated HR Manager can search, filter, and stably paginate employees; open an employee to view current salary and history; and record a valid today-or-future salary change.
3. Invalid employee or salary data, duplicate employee number/email, non-chronological salary changes, and overlapping periods are rejected. Salary periods use inclusive starts and exclusive ends; a new change ends the previous period at its start.
4. Current salary is selected using the stated effective-date rule; future records do not appear as current early, and inactive employees remain visible with their salary history.
5. The three defined insights return results grouped by currency, use current country/department where applicable, exclude inactive or no-current-salary employees from current-salary summaries, and count same-currency increases once per employee per currency in `[start, end)`.
6. Salary-record creation and resulting prior-period end-date changes identify the acting HR Manager. Automated tests cover these rules.
7. The deployed application is usable for a demonstration of the employee, salary-history, salary-change, and insight workflows.
