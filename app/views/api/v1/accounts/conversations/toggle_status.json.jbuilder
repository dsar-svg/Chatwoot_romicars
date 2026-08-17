json.meta do
end

json.payload do
  json.success @status
  json.conversation_id @conversation.display_id
  json.current_status @conversation.status
  json.snoozed_until @conversation.snoozed_until
  json.resolution_type @conversation.resolution_type
  json.resolution_reason @conversation.resolution_reason
  json.resolution_notes @conversation.resolution_notes
  json.resolved_at @conversation.resolved_at
end
