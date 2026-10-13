class SpaController < ActionController::API
  def show
    index = Rails.public_path.join("index.html")
    return head :not_found unless index.file?

    response.headers["Cache-Control"] = "no-cache"
    send_file index, type: "text/html; charset=utf-8", disposition: "inline"
  end
end
