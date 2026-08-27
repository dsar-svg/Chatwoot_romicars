# frozen_string_literal: true

class Api::V2::Accounts::RomicarsAnalyticsController < Api::V1::Accounts::BaseController
  # Profit runs on the customer's own network. Without explicit timeouts a slow or
  # unreachable host held the dashboard request open until Rack::Timeout killed it.
  PROFIT_OPEN_TIMEOUT = 5
  PROFIT_TIMEOUT = 10

  before_action :check_authorization

  def overview
    account  = Current.account
    now      = Time.current
    since_30 = 30.days.ago
    today    = now.beginning_of_day

    convs_30 = account.conversations.where(created_at: since_30..now)
    total    = convs_30.count
    ganado   = convs_30.where(status: :resolved, resolution_type: 'ganado').count

    render json: {
      kpis: {
        total_leads:  total,
        conversion:   total.positive? ? (ganado.to_f / total * 100).round(1) : 0,
        active_chats: account.conversations.where(status: :open).count
      },
      mini_metrics: {
        new_today:      account.contacts.where('created_at >= ?', today).count,
        pending:        account.conversations.where(status: :pending).count,
        high_urgency:   account.conversations.where(priority: %i[high urgent]).where(status: %i[open pending]).count,
        bot:            account.conversations.where(status: :open).where.not(assignee_agent_bot_id: nil).count,
        agent:          account.conversations.where(status: :open).where.not(assignee_id: nil).where(assignee_agent_bot_id: nil).count,
        resolved_today: account.conversations.where(status: :resolved)
                               .where('resolved_at >= ?', today).count
      }
    }
  end

  def mini_metrics_detail
    account = Current.account
    today   = Time.current.beginning_of_day
    type    = params[:type]

    items, label = case type
                   when 'new_today'
                     contacts = account.contacts.where('created_at >= ?', today).order(created_at: :desc).limit(50)
                     [contacts.map { |c| { id: c.id, contact_name: c.name, status: 'Nuevo', agent_name: '—', created_at: c.created_at } }, 'Nuevos Hoy']
                   when 'pending'
                     convs = account.conversations.where(status: :pending).includes(:contact, :assignee).order(created_at: :desc).limit(50)
                     [convs.map { |c| { id: c.display_id, contact_name: c.contact&.name || '—', status: 'Pendiente', agent_name: c.assignee&.name || '—', created_at: c.created_at } }, 'Pendientes']
                   when 'high_urgency'
                     convs = account.conversations.where(priority: %i[high urgent], status: %i[open pending]).includes(:contact, :assignee).order(priority: :desc).limit(50)
                     [convs.map { |c| { id: c.display_id, contact_name: c.contact&.name || '—', status: c.status == 'open' ? 'Abierta' : 'Pendiente', agent_name: c.assignee&.name || '—', created_at: c.created_at } }, 'Alta Urgencia']
                   when 'bot'
                     convs = account.conversations.where(status: :open).where.not(assignee_agent_bot_id: nil).includes(:contact).order(created_at: :desc).limit(50)
                     [convs.map { |c| { id: c.display_id, contact_name: c.contact&.name || '—', status: 'Abierta', agent_name: 'Bot', created_at: c.created_at } }, 'En Bot']
                   when 'agent'
                     convs = account.conversations.where(status: :open).where.not(assignee_id: nil).where(assignee_agent_bot_id: nil).includes(:contact, :assignee).order(created_at: :desc).limit(50)
                     [convs.map { |c| { id: c.display_id, contact_name: c.contact&.name || '—', status: 'Abierta', agent_name: c.assignee&.name || '—', created_at: c.created_at } }, 'En Agente']
                   when 'resolved_today'
                     convs = account.conversations.where(status: :resolved).where('resolved_at >= ?', today).includes(:contact, :assignee).order(resolved_at: :desc).limit(50)
                     [convs.map { |c| { id: c.display_id, contact_name: c.contact&.name || '—', status: 'Resuelta', agent_name: c.assignee&.name || '—', created_at: c.created_at } }, 'Resueltos Hoy']
                   else
                     [[], type]
                   end

    render json: { type: type, label: label, total: items.length, items: items }
  end

  def agents
    account  = Current.account
    since_30 = 30.days.ago

    data = account.agents.map do |agent|
      convs    = account.conversations.where(assignee_id: agent.id, created_at: since_30..Time.current)
      assigned = convs.count
      res      = convs.where(status: :resolved).count

      {
        id:                  agent.id,
        name:                agent.name,
        email:               agent.email,
        avatar_url:          agent.avatar_url,
        assigned:            assigned,
        resolved:            res,
        conversion:          assigned.positive? ? (res.to_f / assigned * 100).round(1) : 0,
        avg_response_minutes: avg_first_response(account, agent.id, since_30)
      }
    end

    render json: data.sort_by { |a| -a[:conversion] }.first(8)
  end

  def demand
    account  = Current.account
    since_30 = 30.days.ago

    inquiries = account.product_inquiries.where(created_at: since_30..Time.current)

    # Aggregated and sorted in SQL by ProductInquiry. Rows written by the n8n flow can
    # arrive without a repuesto or canal; those scopes drop them so the dashboard stops
    # rendering an unlabelled bar.
    top_products = inquiries.top_repuestos(8)
                            .map { |name, count| { name: name, count: count } }

    channel_breakdown = inquiries.by_canal_stats
                                 .map { |canal, count| { channel: canal.to_s.split('::').last.downcase, count: count } }

    render json: {
      popular_products: top_products,
      channel_breakdown: channel_breakdown,
      total_inquiries: inquiries.count
    }
  end

  def ai_insights
    account = Current.account
    ctx     = insights_context(account)
    key     = ENV.fetch('OPENAI_API_KEY', nil) ||
              InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value ||
              InstallationConfig.find_by(name: 'OPENAI_API_KEY')&.value

    raise 'No OpenAI API key configured' if key.blank?

    client   = OpenAI::Client.new(access_token: key)
    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'Eres un analista de negocios experto en autopartes venezolanas. ' \
                     'Analiza los datos del CRM y proporciona exactamente 3 insights estratégicos accionables. ' \
                     'Responde SOLO con un JSON array válido.'
          },
          {
            role: 'user',
            content: "Datos CRM últimos 30 días: #{ctx.to_json}\n\n" \
                     'Proporciona 3 insights en este formato JSON array: ' \
                     '[{"priority":"alta|media|baja","title":"Título","description":"Descripción con datos concretos","action":"Acción recomendada"}]'
          }
        ],
        max_tokens: 900
      }
    )

    content = response.dig('choices', 0, 'message', 'content').to_s.strip
    content = content.gsub(/\A```json?\s*|\s*```\z/, '')
    insights = JSON.parse(content)
    insights = insights.values.first if insights.is_a?(Hash)

    render json: { insights: Array(insights).first(3), source: 'ai' }
  rescue StandardError => e
    Rails.logger.error "RomicarsDashboard AI insights error: #{e.message}"
    render json: { insights: rule_based_insights(account), source: 'rules' }
  end

  def profit
    url = ENV.fetch('PROFIT_API_URL', nil)
    return render json: empty_profit unless url.present?

    token = authenticate_profit(url)
    return render json: empty_profit unless token

    products = fetch_profit_products(url, token)
    customers = fetch_profit_customers(url, token)

    render json: { products_top: products[:top], products_bottom: products[:bottom],
                   customers: customers, available: true }
  rescue StandardError => e
    Rails.logger.error "RomicarsDashboard Profit error: #{e.message}"
    render json: empty_profit.merge(error: e.message)
  end

  def resolution
    account  = Current.account
    since_30 = 30.days.ago

    # This endpoint reports itself as "30 días" but used to query all history, so the
    # percentages never matched the daily/by_agent series below them.
    resolved = account.conversations
                      .where(status: :resolved, resolution_type: Conversation::RESOLUTION_TYPES)
                      .where(resolved_at: since_30..)

    # One grouped query instead of ~10 separate COUNT round trips.
    counts_by_type = resolved.group(:resolution_type).count
    total_resolved = counts_by_type.values.sum

    perdido_by_reason = resolved.where(resolution_type: 'perdido').group(:resolution_reason).count
    sales             = resolved.where(resolution_type: 'ganado').with_sale
    sales_count       = sales.count
    total_sales_amount = sales.sum(:sale_amount).to_f

    render json: {
      period: '30 días',
      total_resolved: total_resolved,
      ganado: {
        count: counts_by_type.fetch('ganado', 0),
        percentage: percentage_of(counts_by_type.fetch('ganado', 0), total_resolved),
        total_sales_amount: total_sales_amount,
        average_sale: sales_count.positive? ? (total_sales_amount / sales_count).round(2) : 0,
        sales: sales.includes(:contact).order(sale_date: :desc).limit(20).map do |c|
          {
            id: c.display_id,
            amount: c.sale_amount.to_f,
            date: c.sale_date,
            invoice: c.sale_invoice,
            contact: c.contact.try(:name)
          }
        end
      },
      perdido: {
        count: counts_by_type.fetch('perdido', 0),
        percentage: percentage_of(counts_by_type.fetch('perdido', 0), total_resolved),
        by_reason: Conversation::RESOLUTION_REASONS.index_with { |reason| perdido_by_reason.fetch(reason, 0) }
      },
      consulta: {
        count: counts_by_type.fetch('consulta', 0),
        percentage: percentage_of(counts_by_type.fetch('consulta', 0), total_resolved)
      },
      daily: daily_resolution_stats(account, since_30),
      by_agent: agent_resolution_stats(account, since_30)
    }
  end

  def requested_products
    account  = Current.account
    since_30 = 30.days.ago

    scope = account.conversations
                   .where(status: :resolved, resolution_reason: Conversation::RESOLUTION_REASON_REQUIRING_PRODUCT)
                   .where.not(requested_product: [nil, ''])
                   .where(resolved_at: since_30..)

    # Totals come from SQL over the whole window. They used to be derived from a
    # `limit(100)` slice, so both counters silently capped at 100 once the shop had a
    # busy month.
    counts_by_product = scope.group(:requested_product).count
    total_requested   = counts_by_product.values.sum

    # Only the sample of conversations shown under each product is capped.
    recent = scope.includes(:contact).order(resolved_at: :desc).limit(200).group_by(&:requested_product)

    products = counts_by_product.sort_by { |_, count| -count }.to_h do |product, count|
      [
        product,
        {
          count: count,
          conversations: recent.fetch(product, []).map do |c|
            {
              id: c.display_id,
              product: c.requested_product,
              contact: c.contact.try(:name),
              resolved_at: c.resolved_at,
              resolution_notes: c.resolution_notes
            }
          end
        }
      ]
    end

    render json: {
      period: '30 días',
      total_requested: total_requested,
      unique_products: counts_by_product.size,
      products: products
    }
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def percentage_of(part, total)
    return 0 unless total.to_i.positive?

    (part.to_f / total * 100).round(1)
  end

  # Averaged in SQL. The Ruby version loaded every conversation of every agent into
  # memory just to subtract two timestamps.
  def avg_first_response(account, agent_id, since)
    average = account.conversations
                     .where(assignee_id: agent_id, created_at: since..Time.current)
                     .where.not(first_reply_created_at: nil)
                     .average(Arel.sql('EXTRACT(EPOCH FROM (first_reply_created_at - conversations.created_at)) / 60'))

    average.to_f.round(1)
  end

  def insights_context(account)
    since_30 = 30.days.ago
    convs    = account.conversations.where(created_at: since_30..Time.current)
    total    = convs.count
    ganado   = convs.where(status: :resolved, resolution_type: 'ganado').count

    {
      period: '30 días',
      total_conversations: total,
      resolved: convs.where(status: :resolved).count,
      pending: convs.where(status: :pending).count,
      open: convs.where(status: :open).count,
      conversion_pct: total.positive? ? (ganado.to_f / total * 100).round(1) : 0,
      high_urgency: convs.where(priority: %i[high urgent]).count,
      unassigned: convs.where(assignee_id: nil).count,
      agents_count: account.agents.count,
      channels: convs.joins(:inbox).group('inboxes.channel_type').count
                     .map { |k, v| "#{k.to_s.split('::').last}: #{v}" }.first(4)
    }
  end

  def rule_based_insights(account)
    since_30 = 30.days.ago
    convs    = account.conversations.where(created_at: since_30..Time.current)
    total    = convs.count
    resolved = convs.where(status: :resolved).count
    conv_pct = total.positive? ? (resolved.to_f / total * 100).round(1) : 0
    unassigned  = convs.where(status: :open, assignee_id: nil).count
    high_urgency = convs.where(priority: %i[high urgent]).count

    insights = []

    if conv_pct < 20
      insights << {
        priority: 'alta', title: 'Conversión por debajo del objetivo',
        description: "Tasa actual: #{conv_pct}% (objetivo ≥ 20%). #{total} conversaciones, #{resolved} resueltas en 30 días.",
        action: 'Revisar proceso de seguimiento y asignar agentes a conversaciones sin resolver.'
      }
    end

    if unassigned > 3
      insights << {
        priority: 'alta', title: "#{unassigned} conversaciones sin agente",
        description: "#{unassigned} chats abiertos sin asignación impactan el tiempo de respuesta.",
        action: 'Activar auto-asignación o distribuir manualmente entre el equipo.'
      }
    end

    if high_urgency.positive?
      insights << {
        priority: 'media', title: "#{high_urgency} conversaciones urgentes",
        description: "#{high_urgency} chats marcados como alta prioridad o urgente requieren atención.",
        action: 'Asignar a los agentes más disponibles y hacer seguimiento inmediato.'
      }
    end

    # Padding used to append the same card up to three times, so an account with nothing
    # to flag saw "Sistema operando con normalidad" repeated three times.
    if insights.empty?
      insights << {
        priority: 'baja', title: 'Sistema operando con normalidad',
        description: "#{total} conversaciones registradas, #{resolved} resueltas. Sin alertas en los últimos 30 días.",
        action: 'Añade OPENAI_API_KEY al entorno del servidor para habilitar análisis con IA.'
      }
    end

    insights.first(3)
  end

  def empty_profit
    { products_top: [], products_bottom: [], customers: [], available: false }
  end

  def profit_connection(url)
    Faraday.new(url: url.chomp('/')) do |conn|
      conn.options.open_timeout = PROFIT_OPEN_TIMEOUT
      conn.options.timeout = PROFIT_TIMEOUT
    end
  end

  def authenticate_profit(url)
    resp = profit_connection(url).post(
      '/api/auth',
      { usuario: ENV.fetch('PROFIT_API_USER', nil), clave: ENV.fetch('PROFIT_API_PASSWORD', nil) }.to_json,
      'Content-Type' => 'application/json'
    )
    return nil unless resp.success?

    JSON.parse(resp.body)['token']
  rescue StandardError => e
    Rails.logger.error "Profit auth: #{e.message}"
    nil
  end

  def fetch_profit_products(url, token)
    resp = profit_connection(url).get(
      '/api/productos/mas-vendidos',
      {},
      'Authorization' => "Bearer #{token}"
    )
    return { top: [], bottom: [] } unless resp.success?

    raw  = JSON.parse(resp.body)
    list = raw.is_a?(Array) ? raw : (raw['productos'] || raw['data'] || [])
    sorted = list.sort_by { |p| -(p['cantidad_vendida'] || p['cantidad'] || 0).to_i }

    { top: sorted.first(6), bottom: sorted.last(6).reverse }
  rescue StandardError => e
    Rails.logger.error "Profit products: #{e.message}"
    { top: [], bottom: [] }
  end

  def fetch_profit_customers(url, token)
    resp = profit_connection(url).get(
      '/api/clientes/ubicacion',
      {},
      'Authorization' => "Bearer #{token}"
    )
    return [] unless resp.success?

    raw = JSON.parse(resp.body)
    raw.is_a?(Array) ? raw.first(200) : (raw['clientes'] || raw['data'] || []).first(200)
  rescue StandardError => e
    Rails.logger.error "RomicarsCustomers Profit error: #{e.message}"
    []
  end

  # Both series excluded `consulta`, so the "Consulta" column in the daily and per-agent
  # tables of the resolution report was permanently zero.
  def daily_resolution_stats(account, since)
    account.conversations
           .where(status: :resolved, resolution_type: Conversation::RESOLUTION_TYPES)
           .where(resolved_at: since..)
           .group(Arel.sql('DATE(resolved_at)'))
           .group(:resolution_type)
           .count
           .map { |(date, type), count| { date: date.to_s, type: type, count: count } }
  end

  def agent_resolution_stats(account, since)
    account.conversations
           .where(status: :resolved, resolution_type: Conversation::RESOLUTION_TYPES)
           .where(resolved_at: since..)
           .where.not(assignee_id: nil)
           .joins('LEFT JOIN users ON users.id = conversations.assignee_id')
           .group('users.name')
           .group(:resolution_type)
           .count
           .map { |(name, type), count| { agent: name, type: type, count: count } }
  end
end
