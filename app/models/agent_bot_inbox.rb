# == Schema Information
#
# Table name: agent_bot_inboxes
#
#  id           :bigint           not null, primary key
#  status       :integer          default("active")
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :integer
#  agent_bot_id :integer
#  inbox_id     :integer
#

class AgentBotInbox < ApplicationRecord
  validates :inbox_id, presence: true
  validates :agent_bot_id, presence: true
  before_validation :ensure_account_id

  belongs_to :inbox
  belongs_to :agent_bot
  belongs_to :account
  enum status: { active: 0, inactive: 1 }

  # Disconnecting the bot from an inbox left the conversations it already held assigned to it, and
  # the bot kept answering them. They go to the sellers instead, the same as any handover.
  after_destroy_commit :release_conversations
  after_update_commit :release_conversations, if: -> { saved_change_to_status? && inactive? }

  private

  def release_conversations
    Conversations::ReleaseBotJob.perform_later(inbox_id, agent_bot_id)
  end

  def ensure_account_id
    self.account_id = inbox&.account_id
  end
end
