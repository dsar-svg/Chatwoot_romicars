# frozen_string_literal: true

class Api::V2::Accounts::RomicarsAnalyticsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def overview
    account  = Current.account
    now      = Time.current
    since_30 = 30.days.ago
    today    = now.beginning_of_day

    convs_30 = account.conversations.where(created_at: since_30..now)
    total    = convs_30.count
    resolved = convs_30.where(status: :resolved).count

    render json: {
      kpis: {
        total_leads:  total,
        conversion:   total.positive? ? (resolved.to_f / total * 100).round(1) : 0,
        active_chats: account.conversations.where(status: :open).count
      },
      mini_metrics: {
        new_today:    account.conversations.where(created_at: today..now).count,
        pending:      account.conversations.where(status: :pending).count,
        high_urgency: account.conversations.where(priority: %i[high urgent]).count,
        unassigned:   account.conversations.where(status: :open, assignee_id: nil).count,
        resolved_today: account.conversations.where(status: :resolved)
                               .where('status_changed_at >= ?', today).count
      }
    }
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

    label_counts = account.conversations
                          .where(created_at: since_30..Time.current)
                          .where.not(cached_label_list: ['', nil])
                          .pluck(:cached_label_list)
                          .flat_map { |l| l.to_s.split(',').map(&:strip) }
                          .reject(&:blank?)
                          .tally
                          .sort_by { |_, v| -v }

    channel_breakdown = account.conversations
                               .where(created_at: since_30..Time.current)
                               .joins(:inbox)
                               .group('inboxes.channel_type')
                               .count
                               .map { |k, v| { channel: k.to_s.split('::').last.downcase, count: v } }

    render json: {
      popular_labels:   label_counts.first(8).map { |term, count| { term: term, count: count } },
      channel_breakdown: channel_breakdown,
      total_30d:        account.conversations.where(created_at: since_30..Time.current).count
    }
  end

  def ai_insights
    account = Current.account
    ctx     = insights_context(account)
    key     = ENV.fetch('OPENAI_API_KEY', nil) ||
              InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value

    raise 'No OpenAI API key configured' unless key.present?

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
  rescue => e
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
  rescue => e
    Rails.logger.error "RomicarsDashboard Profit error: #{e.message}"
    render json: empty_profit.merge(error: e.message)
  end

  def resolution
    account = Current.account
    since_30 = 30.days.ago
    resolved = account.conversations.where(status: :resolved, resolution_type: %w[ganado perdido])

    ganado = resolved.where(resolution_type: 'ganado')
    perdido = resolved.where(resolution_type: 'perdido')

    sales = ganado.with_sale
    total_sales_amount = sales.sum(:sale_amount)

    render json: {
      period: '30 días',
      total_resolved: resolved.count,
      ganado: {
        count: ganado.count,
        percentage: resolved.count.positive? ? (ganado.count.to_f / resolved.count * 100).round(1) : 0,
        total_sales_amount: total_sales_amount.to_f,
        average_sale: sales.count.positive? ? (total_sales_amount.to_f / sales.count).round(2) : 0,
        sales: sales.order(sale_date: :desc).limit(20).map do |c|
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
        count: perdido.count,
        percentage: resolved.count.positive? ? (perdido.count.to_f / resolved.count * 100).round(1) : 0,
        by_reason: {
          sin_stock: perdido.where(resolution_reason: 'sin_stock').count,
          precio: perdido.where(resolution_reason: 'precio').count,
          sin_respuesta: perdido.where(resolution_reason: 'sin_respuesta').count,
          otro: perdido.where(resolution_reason: 'otro').count
        }
      },
      daily: daily_resolution_stats(account, since_30),
      by_agent: agent_resolution_stats(account, since_30)
    }
  end

  def requested_products
    account = Current.account
    since_30 = 30.days.ago

    products = account.conversations
                      .where(status: :resolved, resolution_reason: 'sin_stock')
                      .where.not(requested_product: [nil, ''])
                      .where('resolved_at >= ?', since_30)
                      .order(resolved_at: :desc)
                      .limit(100)

    grouped = products.group_by(&:requested_product)
                      .transform_values do |convs|
                        {
                          count: convs.count,
                          conversations: convs.map do |c|
                            {
                              id: c.display_id,
                              product: c.requested_product,
                              contact: c.contact.try(:name),
                              resolved_at: c.resolved_at,
                              resolution_notes: c.resolution_notes
                            }
                          end
                        }
                      end

    render json: {
      period: '30 días',
      total_requested: products.count,
      unique_products: grouped.keys.count,
      products: grouped.sort_by { |_, v| -v[:count] }.to_h
    }
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def avg_first_response(account, agent_id, since)
    convs = account.conversations
                   .where(assignee_id: agent_id, created_at: since..Time.current)
                   .where.not(first_reply_created_at: nil)
    return 0 if convs.empty?

    total = convs.sum { |c| ((c.first_reply_created_at - c.created_at) / 60).to_i }
    (total.to_f / convs.count).round(1)
  end

  def insights_context(account)
    since_30 = 30.days.ago
    convs    = account.conversations.where(created_at: since_30..Time.current)
    total    = convs.count
    resolved = convs.where(status: :resolved).count

    {
      period: '30 días',
      total_conversations: total,
      resolved: resolved,
      pending: convs.where(status: :pending).count,
      open: convs.where(status: :open).count,
      conversion_pct: total.positive? ? (resolved.to_f / total * 100).round(1) : 0,
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

    insights << {
      priority: 'baja', title: 'Sistema operando con normalidad',
      description: "#{total} conversaciones registradas. Configura OpenAI para insights avanzados.",
      action: 'Añade OPENAI_API_KEY al entorno del servidor para habilitar análisis con IA.'
    } while insights.length < 3

    insights.first(3)
  end

  def empty_profit
    { products_top: [], products_bottom: [], customers: [], available: false }
  end

  def authenticate_profit(url)
    resp = Faraday.post(
      "#{url.chomp('/')}/api/auth",
      { usuario: ENV['PROFIT_API_USER'], clave: ENV['PROFIT_API_PASSWORD'] }.to_json,
      'Content-Type' => 'application/json'
    )
    return nil unless resp.success?

    JSON.parse(resp.body)['token']
  rescue => e
    Rails.logger.error "Profit auth: #{e.message}"
    nil
  end

  def fetch_profit_products(url, token)
    resp = Faraday.get(
      "#{url.chomp('/')}/api/productos/mas-vendidos",
      {},
      'Authorization' => "Bearer #{token}"
    )
    return { top: [], bottom: [] } unless resp.success?

    raw  = JSON.parse(resp.body)
    list = raw.is_a?(Array) ? raw : (raw['productos'] || raw['data'] || [])
    sorted = list.sort_by { |p| -(p['cantidad_vendida'] || p['cantidad'] || 0).to_i }

    { top: sorted.first(6), bottom: sorted.last(6).reverse }
  rescue => e
    Rails.logger.error "Profit products: #{e.message}"
    { top: [], bottom: [] }
  end

  def fetch_profit_customers(url, token)
    resp = Faraday.get(
      "#{url.chomp('/')}/api/clientes/ubicacion",
      {},
      'Authorization' => "Bearer #{token}"
    )
    return [] unless resp.success?

    raw = JSON.parse(resp.body)
    raw.is_a?(Array) ? raw.first(200) : (raw['clientes'] || raw['data'] || []).first(200)
  rescue => e
    Rails.logger.error "RomicarsCustomers Profit error: #{e.message}"
    []
  end

  def daily_resolution_stats(account, since)
    account.conversations
           .where(status: :resolved, resolution_type: %w[ganado perdido])
           .where('resolved_at >= ?', since)
           .group("DATE(resolved_at)")
           .group(:resolution_type)
           .count
           .map { |(date, type), count| { date: date.to_s, type: type, count: count } }
  end

  def agent_resolution_stats(account, since)
    account.conversations
           .where(status: :resolved, resolution_type: %w[ganado perdido])
           .where('resolved_at >= ?', since)
           .where.not(assignee_id: nil)
           .joins("LEFT JOIN users ON users.id = conversations.assignee_id")
           .group('users.name')
           .group(:resolution_type)
           .count
           .map { |(name, type), count| { agent: name, type: type, count: count } }
  end
end
