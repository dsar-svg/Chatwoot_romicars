class Api::V1::Integrations::WebhooksController < ApplicationController
  def create
    builder = Integrations::Slack::IncomingMessageBuilder.new(permitted_params)
    response = builder.perform
    render json: response
  end

  private

  def permitted_params
    params.permit(:token, :type, :challenge, event: [:type, :user, :subtype, :text, :channel, :ts,
      message: [:text, :user, :subtype, :ts], item: [:channel, :ts]], team_id: {}, api_app_id: {},
      event_id: {}, event_time: {})
  end
end
