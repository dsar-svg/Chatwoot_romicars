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
  json.sale_amount @conversation.sale_amount
  json.sale_date @conversation.sale_date
  json.sale_invoice @conversation.sale_invoice
  json.requested_product @conversation.requested_product
end
