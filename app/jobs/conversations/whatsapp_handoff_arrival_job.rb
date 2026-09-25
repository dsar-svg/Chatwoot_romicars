class Conversations::WhatsappHandoffArrivalJob < ApplicationJob
  queue_as :high

  def perform(message)
    WhatsappHandoff.claim(message)
  end
end
