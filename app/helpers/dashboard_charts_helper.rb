# Small inline-SVG charts for the dashboard (no chart library needed):
# sparklines in the summary cards, the monthly line chart and the donut.
module DashboardChartsHelper
  # Smooth line through the points (Catmull-Rom converted to cubic Bezier).
  def dashboard_smooth_path(points)
    return "" if points.empty?
    return "M#{points[0][0]},#{points[0][1]}" if points.size == 1

    path = +"M#{points[0][0].round(1)},#{points[0][1].round(1)}"
    points.each_cons(2).with_index do |(p1, p2), index|
      p0 = index.zero? ? p1 : points[index - 1]
      p3 = points[index + 2] || p2
      c1 = [p1[0] + (p2[0] - p0[0]) / 6.0, p1[1] + (p2[1] - p0[1]) / 6.0]
      c2 = [p2[0] - (p3[0] - p1[0]) / 6.0, p2[1] - (p3[1] - p1[1]) / 6.0]
      path << " C#{c1[0].round(1)},#{c1[1].round(1)} #{c2[0].round(1)},#{c2[1].round(1)} #{p2[0].round(1)},#{p2[1].round(1)}"
    end
    path
  end

  def dashboard_sparkline(values, color:, id:, width: 120, height: 40)
    values = Array(values).map(&:to_f)
    values = [0, 0] if values.size < 2
    max = [values.max, 1].max
    step = width.to_f / (values.size - 1)
    points = values.each_with_index.map { |value, index| [index * step, height - 4 - (value / max) * (height - 8)] }
    line = dashboard_smooth_path(points)
    area = "#{line} L#{width},#{height} L0,#{height} Z"

    content_tag(:svg, class: "dash-spark", viewBox: "0 0 #{width} #{height}", preserveAspectRatio: "none", aria: { hidden: true }) do
      safe_join([
        tag.defs(tag.linearGradient(safe_join([
          tag.stop(offset: "0%", "stop-color": color, "stop-opacity": "0.28"),
          tag.stop(offset: "100%", "stop-color": color, "stop-opacity": "0")
        ]), id: id, x1: "0", y1: "0", x2: "0", y2: "1")),
        tag.path(d: area, fill: "url(##{id})"),
        tag.path(d: line, fill: "none", stroke: color, "stroke-width": "2.2", "stroke-linecap": "round")
      ])
    end
  end

  # series: [{ label:, color:, values: [] }], labels: month names
  def dashboard_line_chart(series, labels, width: 640, height: 240)
    left = 30
    right = 12
    top = 12
    bottom = 28
    plot_w = width - left - right
    plot_h = height - top - bottom
    max_value = series.flat_map { |s| s[:values] }.max.to_i
    y_max = dashboard_nice_max(max_value)
    ticks = 5
    step_x = labels.size > 1 ? plot_w.to_f / (labels.size - 1) : plot_w
    y_for = ->(value) { top + plot_h - (value.to_f / y_max) * plot_h }

    grid = (0..ticks).map do |i|
      value = (y_max / ticks.to_f * i)
      y = y_for.call(value)
      safe_join([
        tag.line(x1: left, x2: width - right, y1: y.round(1), y2: y.round(1), class: "dash-chart__grid"),
        tag.text((value % 1).zero? ? value.to_i : value.round(1), x: left - 8, y: (y + 4).round(1), class: "dash-chart__tick", "text-anchor": "end")
      ])
    end

    x_labels = labels.each_with_index.map do |label, index|
      tag.text(label, x: (left + index * step_x).round(1), y: height - 8, class: "dash-chart__tick", "text-anchor": "middle")
    end

    lines = series.each_with_index.map do |s, s_index|
      points = s[:values].each_with_index.map { |value, index| [left + index * step_x, y_for.call(value)] }
      path = dashboard_smooth_path(points)
      gradient_id = "dash-line-#{s_index}"
      area = "#{path} L#{points.last[0].round(1)},#{top + plot_h} L#{points.first[0].round(1)},#{top + plot_h} Z"
      safe_join([
        tag.defs(tag.linearGradient(safe_join([
          tag.stop(offset: "0%", "stop-color": s[:color], "stop-opacity": s_index.zero? ? "0.22" : "0.1"),
          tag.stop(offset: "100%", "stop-color": s[:color], "stop-opacity": "0")
        ]), id: gradient_id, x1: "0", y1: "0", x2: "0", y2: "1")),
        tag.path(d: area, fill: "url(##{gradient_id})"),
        tag.path(d: path, fill: "none", stroke: s[:color], "stroke-width": "2.5", "stroke-linecap": "round"),
        safe_join(points.each_with_index.map do |(x, y), index|
          tag.circle(cx: x.round(1), cy: y.round(1), r: 4, fill: s[:color], stroke: "#ffffff", "stroke-width": "2") do
            tag.title("#{s[:label]} - #{labels[index]}: #{s[:values][index]}")
          end
        end)
      ])
    end

    content_tag(:svg, class: "dash-chart", viewBox: "0 0 #{width} #{height}", role: "img", aria: { label: "Monthly procurement activity" }) do
      safe_join(grid + x_labels + lines)
    end
  end

  # segments: [{ label:, value:, color: }]
  def dashboard_donut(segments, size: 180, stroke: 28)
    total = segments.sum { |segment| segment[:value].to_i }
    radius = (size - stroke) / 2.0
    circumference = 2 * Math::PI * radius
    offset = 0.0

    arcs = segments.reject { |segment| segment[:value].to_i.zero? }.map do |segment|
      length = total.zero? ? 0 : circumference * segment[:value].to_f / total
      arc = tag.circle(cx: size / 2.0, cy: size / 2.0, r: radius.round(2), fill: "none", stroke: segment[:color],
                       "stroke-width": stroke, "stroke-dasharray": "#{length.round(2)} #{(circumference - length).round(2)}",
                       "stroke-dashoffset": (-offset).round(2), transform: "rotate(-90 #{size / 2.0} #{size / 2.0})") do
        tag.title("#{segment[:label]}: #{segment[:value]}")
      end
      offset += length
      arc
    end

    content_tag(:svg, class: "dash-donut", viewBox: "0 0 #{size} #{size}", role: "img", aria: { label: "Status distribution" }) do
      safe_join([
        tag.circle(cx: size / 2.0, cy: size / 2.0, r: radius.round(2), fill: "none", stroke: "#eef3f0", "stroke-width": stroke),
        *arcs,
        tag.text(total, x: size / 2.0, y: size / 2.0 + 4, class: "dash-donut__total", "text-anchor": "middle"),
        tag.text("Total", x: size / 2.0, y: size / 2.0 + 24, class: "dash-donut__label", "text-anchor": "middle")
      ])
    end
  end

  def dashboard_nice_max(value)
    return 4 if value <= 4

    magnitude = 10**Math.log10(value).floor
    [1, 2, 2.5, 5, 10].map { |m| m * magnitude }.find { |candidate| candidate >= value } || value
  end

  # 33 -> "↑ 33%", 0 -> "0%", nil -> "New"
  def dashboard_trend_label(percent)
    return "New" if percent.nil?
    return "0%" if percent.zero?

    "↑ #{percent}%"
  end

  def dashboard_notification_style(notification)
    text = "#{notification.title} #{notification.message}".downcase
    case text
    when /reject|return/ then [:approval, "red"]
    when /invoice|payment|accepted/ then [:bank, "green"]
    when /vendor|registration/ then [:people, "blue"]
    when /purchase order|po\b/ then [:document, "amber"]
    when /quotation|proposal|rfp/ then [:document, "orange"]
    when /product/ then [:layers, "purple"]
    when /pending|approval/ then [:approval, "red"]
    else [:document, "slate"]
    end
  end

  def dashboard_stage_tone(stage)
    case stage.kind
    when :selected then "green"
    when :approval, :thematic_head then stage.mine ? "red" : "amber"
    when :returned, :max_rate then "orange"
    when :scoring, :vendor_selection then "purple"
    when :vendor_response then "blue"
    else "slate"
    end
  end
end
