# frozen_string_literal: true

class Api::V2::Accounts::RomicarsAnalyticsController < Api::V1::Accounts::BaseController
  # Profit runs on the customer's own network. Without explicit timeouts a slow or
  # unreachable host held the dashboard request open until Rack::Timeout killed it.
  PROFIT_OPEN_TIMEOUT = 5
  PROFIT_TIMEOUT = 10

  AI_INSIGHTS_CACHE_TTL = 3.hours
  AI_INSIGHTS_COUNT = 6
  AI_REQUEST_TIMEOUT = 45

  COUNT_DESC = Arel.sql('COUNT(*) DESC')
  FIRST_RESPONSE_MINUTES = Arel.sql('EXTRACT(EPOCH FROM (first_reply_created_at - conversations.created_at)) / 60')
  # Same two places Campaigns::AudienceResolver reads: the contact's own city field, which
  # writes to additional_attributes, and the `estado` custom attribute. City first because
  # a town is worth more on a map than the state it sits in; `estado` last so a contact
  # that only has the state still gets plotted, on its capital.
  CONTACT_CITY = Arel.sql(
    "NULLIF(TRIM(COALESCE(NULLIF(contacts.additional_attributes->>'city', ''), " \
    "NULLIF(contacts.location, ''), contacts.custom_attributes->>'estado', '')), '')"
  )

  AI_SYSTEM_PROMPT = <<~PROMPT
    Eres analista comercial de una tienda venezolana de repuestos automotrices (RomiCars).
    Recibes métricas de su CRM y tu trabajo es explicar POR QUÉ se pierden ventas y qué
    hacer al respecto, no describir los números.

    Reglas:
    - Compara siempre los cierres ganados contra los perdidos. El bloque
      `ganado_vs_perdido` trae la misma métrica partida por resultado: úsalo para decir
      qué hicieron distinto las conversaciones que sí cerraron (tiempo de primera
      respuesta, canal, agente, prioridad).
    - Prioriza las causas recurrentes de pérdida sobre los hallazgos aislados. El bloque
      `perdidas` trae el desglose por motivo, los repuestos pedidos que no había en stock
      y las notas que escribieron los agentes al cerrar.
    - Cita cifras concretas del JSON en cada descripción. Nada de generalidades.
    - Cada acción debe ser algo que el dueño o un agente pueda ejecutar esta semana.
    - Si un dato viene en cero o vacío, no inventes: dilo y recomienda cómo empezar a
      registrarlo.
    - Escribe en español de Venezuela, directo y sin relleno.

    Devuelve EXACTAMENTE un objeto JSON con esta forma, con 6 elementos ordenados de
    mayor a menor impacto en la facturación:

    {"insights":[{
      "priority":"alta|media|baja",
      "category":"perdidas|conversion|stock|respuesta|equipo|canales",
      "title":"Título corto y concreto",
      "description":"Qué está pasando, con las cifras del JSON que lo sustentan",
      "action":"Acción específica y ejecutable"
    }]}

    Al menos 2 de los 6 deben ser de categoría `perdidas`, analizando causas raíz.
  PROMPT

  # The win/loss panel never lets the model produce a number: every count comes from
  # SQL and the AI only fills the narrative fields, keyed by the same motivo/clave.
  WIN_LOSS_SYSTEM_PROMPT = <<~PROMPT
    Eres analista comercial de RomiCars, tienda venezolana de repuestos automotrices.
    Recibes cifras YA CALCULADAS del CRM. No recalcules ni inventes números: usa solo
    los que vienen en el JSON, y si citas uno, cítalo exacto.

    Además de las cifras recibes `conversaciones`: transcripciones reales de chats
    ganados y perdidos, con lo que escribió el cliente y lo que respondió el agente.
    LÉELAS. De ahí salen los patrones, no de los totales.

    Tu trabajo tiene tres partes:
    1. `perdidas.causas`: por cada motivo, explica la causa raíz probable (qué falla en
       el proceso, no qué dice el número) y una acción ejecutable esta semana.
    2. `ganadas.practicas`: por cada señal, escribe la práctica concreta que el equipo
       debe repetir y cómo aplicarla más seguido.
    3. `patrones`: hasta 3 por lado, deducidos de leer las transcripciones. Di qué pasó
       de verdad en el chat: qué pidió el cliente, qué contestó el agente, en qué
       momento se cayó o se cerró la venta. En `evidencia` parafrasea lo que se dijo.
       En `conversaciones` pon los `id` exactos que trae el JSON y que sustentan el
       patrón. No inventes un id que no esté en la entrada.

    `conversaciones` solo trae los chats que NO habías leído antes. Los patrones que ya
    sacaste vienen aparte, en `patrones_ya_detectados`. Con los chats nuevos: confirma
    los que siguen vigentes, corrígelos si cambiaron, y reemplaza los que ya no se
    sostienen. Devuelve siempre la lista consolidada, no solo lo nuevo.

    Devuelve EXACTAMENTE este objeto JSON:
    {"perdidas":{"resumen":"1 o 2 frases","causas":{"<motivo>":{"diagnostico":"","accion":""}},
                 "patrones":[{"hallazgo":"","evidencia":"","accion":"","conversaciones":[1,2]}]},
     "ganadas":{"resumen":"1 o 2 frases","practicas":{"<clave>":{"practica":"","accion":""}},
                "patrones":[{"hallazgo":"","evidencia":"","accion":"","conversaciones":[3]}]}}

    Usa como claves exactamente los `motivo` y `clave` que trae el JSON de entrada.
    Español de Venezuela, directo, sin relleno.
  PROMPT

  LOSS_LABELS = {
    'sin_stock' => 'Sin stock',
    'precio' => 'Precio',
    'sin_respuesta' => 'Sin respuesta',
    'otro' => 'Otro'
  }.freeze

  # Used when OpenAI is unavailable, and per field when the model omits one.
  LOSS_DIAGNOSIS = {
    'sin_stock' => 'El cliente pidió un repuesto que no estaba en inventario y no se le ofreció alternativa ni fecha de reposición.',
    'precio' => 'El precio quedó fuera de lo que el cliente esperaba y la conversación cerró sin negociar ni mostrar una opción más económica.',
    'sin_respuesta' => 'El cliente dejó de contestar. Casi siempre es falta de seguimiento después del primer mensaje.',
    'otro' => 'Cierres sin motivo tipificado. Sin la nota del agente no se puede atacar la causa.'
  }.freeze

  LOSS_ACTION = {
    'sin_stock' => 'Cotizar reposición de los repuestos más pedidos sin stock: son demanda ya confirmada.',
    'precio' => 'Definir un rango de descuento que el agente pueda dar sin consultar y una alternativa equivalente más barata.',
    'sin_respuesta' => 'Fijar un segundo contacto a las 24 h y un tercero a las 72 h antes de dar la conversación por perdida.',
    'otro' => 'Exigir nota de cierre al marcar "Otro" para poder tipificar el motivo el mes que viene.'
  }.freeze

  # Transcripts sent to the model. Capped on every axis: the prompt has to stay cheap
  # and the conversations carry customer text.
  SAMPLE_LOST = 12
  SAMPLE_WON = 8
  SAMPLE_MESSAGES = 6
  SAMPLE_MESSAGE_CHARS = 240
  SAMPLE_PATTERNS = 3
  # What the account has already had read, so a refresh spends tokens on new chats only.
  WIN_LOSS_MEMORY_TTL = 30.days
  WIN_LOSS_MEMORY_IDS = 300

  PRIORITY_LABELS = {
    'urgent' => 'urgente',
    'high' => 'alta',
    'medium' => 'media',
    'low' => 'baja'
  }.freeze

  WIN_ACTION = {
    'respuesta' => 'Fijar como meta del equipo ese tiempo de primera respuesta y revisarlo cada semana.',
    'canal' => 'Empujar más tráfico a ese canal y replicar en los demás el guion que se usa allí.',
    'agente' => 'Que ese agente muestre su flujo al resto y usar sus chats ganados como plantilla.',
    'prioridad' => 'Marcar la prioridad al abrir la conversación, no al cerrarla: es lo que dispara el seguimiento.'
  }.freeze

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
                            .map { |(name, marca, modelo), count| { name: name, brand: marca, model: modelo, count: count } }

    channel_breakdown = inquiries.by_canal_stats
                                 .map { |canal, count| { channel: canal.to_s.split('::').last.downcase, count: count } }

    render json: {
      popular_products: top_products,
      channel_breakdown: channel_breakdown,
      total_inquiries: inquiries.count
    }
  end

  # Where the people who write to us are. `without_city` is reported so the map can say how
  # much of the picture is missing instead of implying the shop only sells in four towns.
  def contact_locations
    account = Current.account
    counts = account.contacts
                    .where(id: account.conversations.select(:contact_id))
                    .group(CONTACT_CITY)
                    .count

    located = counts.except(nil)

    render json: {
      locations: located.map { |label, count| { label: label, count: count } }.sort_by { |row| -row[:count] },
      with_city: located.values.sum,
      without_city: counts[nil].to_i
    }
  end

  def ai_insights
    account = Current.account

    # The dashboard auto-refreshes every 5 minutes, so this used to bill an OpenAI call
    # per agent per refresh for numbers that barely move. Only successful AI answers are
    # cached — a transient failure must not pin the rules fallback for hours.
    cached = params[:refresh].blank? ? Redis::Alfred.get(ai_insights_cache_key(account)) : nil
    return render(json: JSON.parse(cached)) if cached.present?

    payload = build_ai_insights(account)
    Redis::Alfred.setex(ai_insights_cache_key(account), payload.to_json, AI_INSIGHTS_CACHE_TTL) if payload[:source] == 'ai'

    render json: payload
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
                      .where(status: :resolved, resolution_type: Conversation::DECLARED_RESOLUTION_TYPES)
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
      # Outside the funnel on purpose: nobody declared an outcome, so there is nothing to
      # take a percentage of. Reported anyway — a number the shop cannot see is a number
      # it cannot act on, and this one measures how many leads go quiet.
      abandonado: {
        count: account.conversations.where(status: :resolved, resolution_type: 'abandonado')
                      .where(resolved_at: since_30..).count
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

  # "Por qué perdimos / qué nos hizo ganar". Same 30-day context as ai_insights, but the
  # counts are rendered as they come out of SQL and the model only writes around them.
  def win_loss
    account = Current.account

    cached = params[:refresh].blank? ? Redis::Alfred.get(win_loss_cache_key(account)) : nil
    return render(json: JSON.parse(cached)) if cached.present?

    payload = build_win_loss(account)
    Redis::Alfred.setex(win_loss_cache_key(account), payload.to_json, AI_INSIGHTS_CACHE_TTL) if payload[:source] == 'ai'

    render json: payload
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
                     .average(FIRST_RESPONSE_MINUTES)

    average.to_f.round(1)
  end

  def ai_insights_cache_key(account)
    "romicars:ai_insights:v2:#{account.id}"
  end

  def openai_api_key
    ENV.fetch('OPENAI_API_KEY', nil).presence ||
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value.presence ||
      InstallationConfig.find_by(name: 'OPENAI_API_KEY')&.value.presence
  end

  def build_ai_insights(account)
    # Built once and reused by the fallback, so a failed OpenAI call does not re-run the
    # ~15 aggregate queries behind the context.
    context = insights_context(account)
    key = openai_api_key
    raise 'No OpenAI API key configured' if key.blank?

    insights = parse_ai_response(request_ai_insights(key, context))
    raise 'AI returned no usable insights' if insights.empty?

    { insights: insights.first(AI_INSIGHTS_COUNT), source: 'ai', generated_at: Time.current }
  rescue StandardError => e
    Rails.logger.error "RomicarsDashboard AI insights error: #{e.class}: #{e.message}"
    # context is nil only if insights_context itself blew up; an empty card list beats a 500.
    { insights: context ? rule_based_insights(context) : [], source: 'rules', generated_at: Time.current }
  end

  def request_ai_insights(key, context)
    request_ai_json(key, AI_SYSTEM_PROMPT, "Datos del CRM (últimos 30 días):\n#{JSON.pretty_generate(context)}")
  end

  def request_ai_json(key, system_prompt, user_content)
    OpenAI::Client.new(access_token: key, request_timeout: AI_REQUEST_TIMEOUT).chat(
      parameters: {
        model: 'gpt-4o-mini',
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: user_content }
        ],
        max_tokens: 2500
      }
    ).dig('choices', 0, 'message', 'content').to_s
  end

  def parse_json_object(content)
    parsed = JSON.parse(content.to_s.strip.gsub(/\A```json?\s*|\s*```\z/, ''))
    parsed.is_a?(Hash) ? parsed : {}
  end

  def parse_ai_response(content)
    parsed = JSON.parse(content.strip.gsub(/\A```json?\s*|\s*```\z/, ''))
    # json_object mode always returns an object, so the array arrives wrapped under some
    # key. Take the first array-valued entry rather than guessing its name.
    parsed = parsed.values.find { |v| v.is_a?(Array) } || [] if parsed.is_a?(Hash)

    Array(parsed).select { |i| i.is_a?(Hash) && i['title'].present? }
  end

  # Everything below feeds the prompt. The old context was volume-only — totals and a
  # channel list — which is why the insights never said anything about *why* deals were
  # being lost. These add the won/lost comparison the shop actually needs.
  def insights_context(account)
    since = 30.days.ago
    convs = account.conversations.where(created_at: since..Time.current)
    resolved = account.conversations
                      .where(status: :resolved, resolution_type: Conversation::DECLARED_RESOLUTION_TYPES)
                      .where(resolved_at: since..)
    by_type = resolved.group(:resolution_type).count
    ganado = by_type.fetch('ganado', 0)
    perdido = by_type.fetch('perdido', 0)

    {
      periodo: '30 días',
      volumen: {
        conversaciones_totales: convs.count,
        abiertas: convs.where(status: :open).count,
        pendientes: convs.where(status: :pending).count,
        sin_asignar: convs.where(status: :open, assignee_id: nil).count,
        alta_urgencia: convs.where(priority: %i[high urgent]).count,
        agentes_activos: account.agents.count
      },
      cierres: {
        ganado: ganado,
        perdido: perdido,
        consulta: by_type.fetch('consulta', 0),
        tasa_conversion_pct: percentage_of(ganado, ganado + perdido)
      },
      ventas: sales_context(resolved),
      perdidas: loss_context(resolved, perdido),
      ganado_vs_perdido: comparison_context(resolved),
      demanda: demand_context(account, since)
    }
  end

  def sales_context(resolved)
    sales = resolved.where(resolution_type: 'ganado').with_sale
    count = sales.count
    total = sales.sum(:sale_amount).to_f

    {
      ventas_con_monto: count,
      monto_total_usd: total.round(2),
      ticket_promedio_usd: count.positive? ? (total / count).round(2) : 0
    }
  end

  def loss_context(resolved, perdido_total)
    lost = resolved.where(resolution_type: 'perdido')
    reasons = lost.group(:resolution_reason).count

    {
      total: perdido_total,
      por_motivo: Conversation::RESOLUTION_REASONS.to_h do |reason|
        count = reasons.fetch(reason, 0)
        [reason, { cantidad: count, pct_de_las_perdidas: percentage_of(count, perdido_total) }]
      end,
      repuestos_pedidos_sin_stock: lost
        .where(resolution_reason: Conversation::RESOLUTION_REASON_REQUIRING_PRODUCT)
        .where.not(requested_product: [nil, ''])
        .group(:requested_product).order(COUNT_DESC).limit(15).count,
      notas_de_cierres_perdidos: lost.where.not(resolution_notes: [nil, ''])
                                     .order(resolved_at: :desc).limit(25).pluck(:resolution_notes)
    }
  end

  # The heart of it: same metric, split by outcome, so the model can say what the won
  # deals did differently instead of describing each side in isolation.
  def comparison_context(resolved)
    {
      minutos_primera_respuesta: resolved.where.not(first_reply_created_at: nil)
                                         .group(:resolution_type)
                                         .average(FIRST_RESPONSE_MINUTES)
                                         .transform_values { |v| v.to_f.round(1) },
      por_canal: nest_pair_counts(resolved.joins(:inbox).group('inboxes.channel_type').group(:resolution_type).count),
      por_agente: nest_pair_counts(
        resolved.where.not(assignee_id: nil)
                .joins('LEFT JOIN users ON users.id = conversations.assignee_id')
                .group('users.name').group(:resolution_type).count
      ),
      por_prioridad: nest_pair_counts(resolved.group(:priority).group(:resolution_type).count)
    }
  end

  def demand_context(account, since)
    inquiries = account.product_inquiries.where(created_at: since..Time.current)
    total = inquiries.count
    missing = inquiries.not_found.count

    {
      consultas_registradas: total,
      no_encontrados: missing,
      pct_no_encontrado: percentage_of(missing, total),
      mas_buscados: inquiries.top_repuestos(10).map do |(repuesto, marca, modelo), count|
        { repuesto: repuesto, marca: marca, modelo: modelo, veces: count }
      end,
      no_encontrados_mas_buscados: inquiries.not_found_repuestos(10).map do |(repuesto, marca, modelo), count|
        { repuesto: repuesto, marca: marca, modelo: modelo, veces: count }
      end
    }
  end

  # `group(a).group(b).count` keys on [a, b] tuples, which serialise to JSON as unreadable
  # stringified arrays. Nest them so the prompt stays legible.
  def nest_pair_counts(counts)
    counts.each_with_object({}) do |((outer, inner), count), acc|
      label = outer.to_s.split('::').last.to_s
      label = 'sin_definir' if label.blank?
      (acc[label] ||= {})[inner.to_s] = count
    end
  end

  # Fallback when OpenAI is unavailable. Built from the same context as the prompt so it
  # covers the same ground — losses first — instead of only volume alerts.
  def rule_based_insights(ctx)
    insights = loss_rule_insights(ctx) + operations_rule_insights(ctx)

    if insights.empty?
      insights << {
        priority: 'baja', category: 'conversion',
        title: 'Sin alertas en los últimos 30 días',
        description: "#{ctx[:volumen][:conversaciones_totales]} conversaciones, " \
                     "#{ctx[:cierres][:ganado]} ganadas y #{ctx[:cierres][:perdido]} perdidas.",
        action: 'Configura OPENAI_API_KEY para habilitar el análisis con IA.'
      }
    end

    insights.first(AI_INSIGHTS_COUNT)
  end

  def loss_rule_insights(ctx)
    perdidas = ctx[:perdidas]
    return [] unless perdidas[:total].positive?

    insights = []
    top_reason, top_data = perdidas[:por_motivo].max_by { |_, data| data[:cantidad] }

    if top_data && top_data[:cantidad].positive?
      insights << {
        priority: 'alta', category: 'perdidas',
        title: "Motivo principal de pérdida: #{top_reason.tr('_', ' ')}",
        description: "#{top_data[:cantidad]} de #{perdidas[:total]} cierres perdidos " \
                     "(#{top_data[:pct_de_las_perdidas]}%) se fueron por este motivo.",
        action: 'Revisar las notas de esos cierres y atacar la causa raíz antes que el volumen.'
      }
    end

    top_missing = perdidas[:repuestos_pedidos_sin_stock].first(3)
    if top_missing.any?
      listado = top_missing.map { |producto, veces| "#{producto} (#{veces})" }.join(', ')
      insights << {
        priority: 'alta', category: 'stock',
        title: 'Ventas perdidas por falta de stock',
        description: "Repuestos más pedidos que no había: #{listado}.",
        action: 'Cotizar reposición de estos códigos; son demanda ya confirmada.'
      }
    end

    tiempos = ctx[:ganado_vs_perdido][:minutos_primera_respuesta]
    if tiempos['ganado'] && tiempos['perdido'] && tiempos['perdido'] > tiempos['ganado']
      insights << {
        priority: 'media', category: 'respuesta',
        title: 'Respondemos más lento lo que perdemos',
        description: "Primera respuesta: #{tiempos['ganado']} min en las ganadas vs " \
                     "#{tiempos['perdido']} min en las perdidas.",
        action: 'Fijar un objetivo de primera respuesta cercano al de las conversaciones ganadas.'
      }
    end

    insights
  end

  def operations_rule_insights(ctx)
    volumen = ctx[:volumen]
    demanda = ctx[:demanda]
    insights = []

    if volumen[:sin_asignar] > 3
      insights << {
        priority: 'alta', category: 'equipo',
        title: "#{volumen[:sin_asignar]} conversaciones sin agente",
        description: "#{volumen[:sin_asignar]} chats abiertos sin asignación impactan el tiempo de respuesta.",
        action: 'Activar auto-asignación o distribuirlas manualmente entre el equipo.'
      }
    end

    if ctx[:cierres][:tasa_conversion_pct] < 20 && (ctx[:cierres][:ganado] + ctx[:cierres][:perdido]).positive?
      insights << {
        priority: 'alta', category: 'conversion',
        title: 'Conversión por debajo del objetivo',
        description: "#{ctx[:cierres][:tasa_conversion_pct]}% de cierres ganados sobre " \
                     "#{ctx[:cierres][:ganado] + ctx[:cierres][:perdido]} conversaciones cerradas (objetivo ≥ 20%).",
        action: 'Revisar el proceso de seguimiento de las conversaciones que quedan sin cerrar.'
      }
    end

    if demanda[:pct_no_encontrado] > 25
      insights << {
        priority: 'media', category: 'stock',
        title: "#{demanda[:pct_no_encontrado]}% de las consultas no encuentran el repuesto",
        description: "#{demanda[:no_encontrados]} de #{demanda[:consultas_registradas]} búsquedas del bot no dieron resultado.",
        action: 'Revisar el catálogo y los sinónimos de los repuestos más buscados sin resultado.'
      }
    end

    if volumen[:alta_urgencia].positive?
      insights << {
        priority: 'media', category: 'equipo',
        title: "#{volumen[:alta_urgencia]} conversaciones urgentes",
        description: "#{volumen[:alta_urgencia]} chats marcados como alta prioridad o urgente requieren atención.",
        action: 'Asignarlas a los agentes disponibles y hacer seguimiento inmediato.'
      }
    end

    insights
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
           .where(status: :resolved, resolution_type: Conversation::DECLARED_RESOLUTION_TYPES)
           .where(resolved_at: since..)
           .group(Arel.sql('DATE(resolved_at)'))
           .group(:resolution_type)
           .count
           .map { |(date, type), count| { date: date.to_s, type: type, count: count } }
  end

  def agent_resolution_stats(account, since)
    account.conversations
           .where(status: :resolved, resolution_type: Conversation::DECLARED_RESOLUTION_TYPES)
           .where(resolved_at: since..)
           .where.not(assignee_id: nil)
           .joins('LEFT JOIN users ON users.id = conversations.assignee_id')
           .group('users.name')
           .group(:resolution_type)
           .count
           .map { |(name, type), count| { agent: name, type: type, count: count } }
  end

  def win_loss_cache_key(account)
    "romicars:win_loss:v1:#{account.id}"
  end

  def build_win_loss(account)
    memory = win_loss_memory(account)
    facts = win_loss_facts(insights_context(account))
    # Transcripts go to the model only. They are not part of the response: the panel
    # shows conclusions and links, not the customer's messages.
    samples = conversation_samples(account, memory)
    narrative = win_loss_narrative(facts, samples, memory)

    payload = apply_win_loss_narrative(facts, narrative[:body], samples, memory)
              .merge(source: narrative[:source],
                     conversaciones_nuevas: narrative[:read] ? samples.values.sum(&:size) : 0,
                     generated_at: Time.current)

    store_win_loss_memory(account, memory, samples, payload, narrative) if narrative[:source] == 'ai'
    payload
  end

  # The numbers already live in `facts`; a failed or missing AI call only costs the
  # narrative, which `apply_win_loss_narrative` then fills from the static copy.
  def win_loss_narrative(facts, samples, memory)
    key = openai_api_key
    raise 'No OpenAI API key configured' if key.blank?

    # Nothing left to read: reuse the last answer instead of paying to re-read the same
    # chats. The counts around it are recomputed on every request either way.
    stored = memory['narrative']
    return { body: stored, source: 'ai', read: false } if samples.values.all?(&:empty?) && stored.present?

    payload = facts.merge(conversaciones: samples, patrones_ya_detectados: stored_patterns(memory))
    body = parse_json_object(
      request_ai_json(key, WIN_LOSS_SYSTEM_PROMPT,
                      "Cifras y conversaciones del CRM (últimos 30 días):\n#{JSON.pretty_generate(payload)}")
    )
    raise 'AI returned no usable narrative' if body.blank?

    { body: body, source: 'ai', read: true }
  rescue StandardError => e
    Rails.logger.error "RomicarsDashboard win/loss error: #{e.class}: #{e.message}"
    { body: {}, source: 'rules', read: false }
  end

  def win_loss_memory_key(account)
    "romicars:win_loss:memory:v1:#{account.id}"
  end

  # { 'perdidas' => { 'ids' => [], 'patrones' => [] }, 'ganadas' => {...}, 'narrative' => {} }
  def win_loss_memory(account)
    stored = JSON.parse(Redis::Alfred.get(win_loss_memory_key(account)).presence || '{}')
    stored = {} unless stored.is_a?(Hash)

    {
      'perdidas' => stored['perdidas'].is_a?(Hash) ? stored['perdidas'] : {},
      'ganadas' => stored['ganadas'].is_a?(Hash) ? stored['ganadas'] : {},
      'narrative' => stored['narrative'].is_a?(Hash) ? stored['narrative'] : nil
    }
  rescue JSON::ParserError
    { 'perdidas' => {}, 'ganadas' => {}, 'narrative' => nil }
  end

  def stored_patterns(memory)
    {
      perdidas: Array(memory.dig('perdidas', 'patrones')),
      ganadas: Array(memory.dig('ganadas', 'patrones'))
    }
  end

  def store_win_loss_memory(account, memory, samples, payload, narrative)
    updated = {
      'perdidas' => side_memory(memory['perdidas'], samples[:perdidas], payload[:perdidas][:patrones]),
      'ganadas' => side_memory(memory['ganadas'], samples[:ganadas], payload[:ganadas][:patrones]),
      'narrative' => narrative[:body]
    }

    Redis::Alfred.setex(win_loss_memory_key(account), updated.to_json, WIN_LOSS_MEMORY_TTL)
  end

  # Newest ids first and capped: anything past the cap is older than the 30-day window
  # the panel reports on anyway.
  def side_memory(previous, sample, patterns)
    {
      'ids' => (sample.pluck(:id) + Array(previous['ids'])).uniq.first(WIN_LOSS_MEMORY_IDS),
      'patrones' => patterns
    }
  end

  def conversation_samples(account, memory)
    scope = account.conversations
                   .where(status: :resolved, resolved_at: 30.days.ago..)
                   .includes(:messages, :assignee, :inbox)

    {
      perdidas: transcripts(scope.where(resolution_type: 'perdido'), SAMPLE_LOST, memory.dig('perdidas', 'ids')),
      ganadas: transcripts(scope.where(resolution_type: 'ganado'), SAMPLE_WON, memory.dig('ganadas', 'ids'))
    }
  end

  def transcripts(scope, limit, seen_ids)
    scope = scope.where.not(display_id: seen_ids) if seen_ids.present?

    scope.order(resolved_at: :desc).limit(limit).map do |conversation|
      {
        id: conversation.display_id,
        motivo: conversation.resolution_reason,
        agente: conversation.assignee&.name,
        canal: conversation.inbox&.channel_type.to_s.split('::').last,
        nota_de_cierre: conversation.resolution_notes.presence,
        mensajes: transcript_lines(conversation)
      }
    end
  end

  # First two messages and the last four: the opening tells what the customer asked for,
  # the tail tells how it ended. The middle of a long chat rarely changes the diagnosis.
  def transcript_lines(conversation)
    chat = conversation.messages
                       .reject { |message| message.private? || %w[incoming outgoing].exclude?(message.message_type) }
                       .select { |message| message.content.present? }
                       .sort_by(&:created_at)
    chat = chat.first(2) + chat.last(SAMPLE_MESSAGES - 2) if chat.size > SAMPLE_MESSAGES

    chat.map do |message|
      "#{message.incoming? ? 'cliente' : 'agente'}: #{message.content.to_s.squish.truncate(SAMPLE_MESSAGE_CHARS)}"
    end
  end

  # Every figure here comes from SQL. The AI never produces one.
  def win_loss_facts(ctx)
    perdidas = ctx[:perdidas]

    {
      periodo: ctx[:periodo],
      perdidas: {
        total: perdidas[:total],
        resumen: nil,
        patrones: [],
        causas: loss_causes(perdidas),
        repuestos_sin_stock: perdidas[:repuestos_pedidos_sin_stock].first(6).map do |producto, veces|
          { producto: producto, veces: veces }
        end
      },
      ganadas: {
        total: ctx[:cierres][:ganado],
        tasa_conversion_pct: ctx[:cierres][:tasa_conversion_pct],
        monto_total_usd: ctx[:ventas][:monto_total_usd],
        ticket_promedio_usd: ctx[:ventas][:ticket_promedio_usd],
        resumen: nil,
        patrones: [],
        practicas: win_signals(ctx)
      }
    }
  end

  def loss_causes(perdidas)
    perdidas[:por_motivo].filter_map do |motivo, data|
      next if data[:cantidad].zero?

      {
        motivo: motivo,
        etiqueta: LOSS_LABELS.fetch(motivo, motivo.tr('_', ' ')),
        cantidad: data[:cantidad],
        pct: data[:pct_de_las_perdidas]
      }
    end.sort_by { |causa| -causa[:cantidad] }
  end

  # A "signal" is a metric where the won conversations measurably did something the lost
  # ones did not. Anything without a gap is left out rather than padded into a practice.
  def win_signals(ctx)
    comp = ctx[:ganado_vs_perdido]
    tiempos = comp[:minutos_primera_respuesta]
    signals = []

    if tiempos['ganado'] && tiempos['perdido'] && tiempos['perdido'] > tiempos['ganado']
      signals << { clave: 'respuesta', titulo: 'Contestar rápido el primer mensaje',
                   evidencia: "Primera respuesta: #{tiempos['ganado']} min en las ganadas vs #{tiempos['perdido']} min en las perdidas." }
    end

    if (canal = best_win_rate(comp[:por_canal]))
      signals << { clave: 'canal', titulo: "#{canal[:label].capitalize} es el canal que más cierra",
                   evidencia: "#{canal[:pct]}% ganadas sobre #{canal[:total]} cierres por ese canal." }
    end

    if (agente = best_win_rate(comp[:por_agente]))
      signals << { clave: 'agente', titulo: "#{agente[:label]} cierra mejor que el resto",
                   evidencia: "#{agente[:ganado]} ganadas de #{agente[:total]} cierres (#{agente[:pct]}%)." }
    end

    if (prioridad = best_win_rate(comp[:por_prioridad]))
      etiqueta = PRIORITY_LABELS.fetch(prioridad[:label], prioridad[:label])
      signals << { clave: 'prioridad', titulo: "Las marcadas con prioridad #{etiqueta} cierran más",
                   evidencia: "#{prioridad[:pct]}% ganadas sobre #{prioridad[:total]} cierres con esa prioridad." }
    end

    signals
  end

  # `min_closes` keeps a single lucky sale from being reported as "the best channel".
  def best_win_rate(counts, min_closes = 3)
    counts.filter_map do |label, by_type|
      ganado = by_type['ganado'].to_i
      total  = ganado + by_type['perdido'].to_i
      next if total < min_closes || label == 'sin_definir' || ganado.zero?

      { label: label, ganado: ganado, total: total, pct: percentage_of(ganado, total) }
    end.max_by { |row| [row[:pct], row[:total]] }
  end

  def apply_win_loss_narrative(facts, narrative, samples, memory)
    causas    = narrative.dig('perdidas', 'causas') || {}
    practicas = narrative.dig('ganadas', 'practicas') || {}

    facts[:perdidas][:causas].each do |causa|
      text = causas[causa[:motivo]] || {}
      causa[:diagnostico] = text['diagnostico'].presence || LOSS_DIAGNOSIS.fetch(causa[:motivo], LOSS_DIAGNOSIS['otro'])
      causa[:accion]      = text['accion'].presence || LOSS_ACTION.fetch(causa[:motivo], LOSS_ACTION['otro'])
    end

    facts[:ganadas][:practicas].each do |practica|
      text = practicas[practica[:clave]] || {}
      practica[:practica] = text['practica'].presence || practica[:titulo]
      practica[:accion]   = text['accion'].presence || WIN_ACTION[practica[:clave]]
    end

    facts[:perdidas][:resumen] = narrative.dig('perdidas', 'resumen').presence || default_loss_summary(facts)
    facts[:ganadas][:resumen]  = narrative.dig('ganadas', 'resumen').presence || default_win_summary(facts)

    stored = stored_patterns(memory)
    facts[:perdidas][:patrones] = read_patterns(narrative.dig('perdidas', 'patrones'), samples[:perdidas], stored[:perdidas])
    facts[:ganadas][:patrones]  = read_patterns(narrative.dig('ganadas', 'patrones'), samples[:ganadas], stored[:ganadas])
    facts[:conversaciones_analizadas] = analysed_count(memory, samples)
    facts
  end

  def analysed_count(memory, samples)
    %w[perdidas ganadas].sum do |side|
      (Array(memory.dig(side, 'ids')) + samples[side.to_sym].pluck(:id)).uniq.size
    end
  end

  def read_patterns(raw, sample, stored)
    # A pattern carried over from an earlier run cites conversations that are no longer
    # in the sample; those ids were already validated when they were first stored.
    valid_ids = sample.pluck(:id) | Array(stored).flat_map { |pattern| Array(pattern['conversaciones']) }

    Array(raw).filter_map do |pattern|
      next unless pattern.is_a?(Hash) && pattern['hallazgo'].present?

      {
        hallazgo: pattern['hallazgo'],
        evidencia: pattern['evidencia'],
        accion: pattern['accion'],
        # The model does invent display_ids. Only ids it was actually given survive, so a
        # link in the panel always opens a conversation that exists.
        conversaciones: Array(pattern['conversaciones']).map(&:to_i) & valid_ids
      }
    end.first(SAMPLE_PATTERNS)
  end

  def default_loss_summary(facts)
    top = facts[:perdidas][:causas].first
    return 'Sin cierres perdidos registrados en el período.' if top.blank?

    "#{facts[:perdidas][:total]} conversaciones perdidas. El motivo que más pesa es " \
      "#{top[:etiqueta].downcase} con #{top[:cantidad]} (#{top[:pct]}%)."
  end

  def default_win_summary(facts)
    ganadas = facts[:ganadas]
    return 'Sin cierres ganados registrados en el período.' unless ganadas[:total].positive?

    "#{ganadas[:total]} conversaciones ganadas (#{ganadas[:tasa_conversion_pct]}% de los cierres) " \
      "por #{ganadas[:monto_total_usd]} USD, con ticket promedio de #{ganadas[:ticket_promedio_usd]} USD."
  end
end
