# frozen_string_literal: true

json.payload @faqs do |faq|
  json.id faq.id
  json.question faq.question
  json.answer faq.answer
  json.category faq.category
  json.keywords faq.keywords
  json.active faq.active
  json.priority faq.priority
  json.created_at faq.created_at
  json.updated_at faq.updated_at
end

json.meta {
  json.count @faqs.size
}
