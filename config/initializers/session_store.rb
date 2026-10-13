Rails.application.config.session_store :active_record_store,
  key: "_assessment_salary_session",
  httponly: true,
  same_site: :lax,
  secure: Rails.env.production?
