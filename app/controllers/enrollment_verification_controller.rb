class EnrollmentVerificationController < ApplicationController
  before_filter :api_authenticate

  def get_feed
    render json: MyAcademics::EnrollmentVerification.from_session(session).get_feed_as_json
  end
end
