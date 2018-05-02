require 'google/apis/analyticsreporting_v4'
class AnalyticsReporting
  def initialize(token, view_id, domain = nil)
    @report = Google::Apis::AnalyticsreportingV4::AnalyticsReportingService.new
    @report.authorization = token
    @view_id = view_id
    @domain = domain
  end

  DEFAULT_CHANNELS = %w(Direct Display Paid\ Search Referral Social
                        (Other) Email Organic\ Search Affiliates).freeze

  def setup_correct
    request1 = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:hostname'), google_dimension('ga:landingPagePath')],
      metrics: [google_metric('ga:bounceRate'), google_metric('ga:entrances')],
      date_ranges: [default_date_range]
    )
    request2 = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:fullReferrer')],
      metrics: [],
      date_ranges: [default_date_range]
    )
    response1 = @report.batch_get_reports(request1)
    response2 = @report.batch_get_reports(request2)
    dimensions = row_dimensions(response1)
    metrics = row_metric_values(response1)
    return false unless dimensions && metrics

    results = dimensions.zip(metrics)
    bounce_rate_ok = metrics.select { |x| (x[1].to_i > 100) && ((x[0].to_f < 5) || (x[0].to_f > 90))}.count == 0

    not_set = results.select { |x| x[0][1] == '(not set)' }
    not_set_count = not_set.map { |x| x[1][1].to_i }.inject(:+)
    total_count = results.map { |x| x[1][1].to_i }.inject(:+)
    not_set_percentage_ok = not_set_count.to_f / total_count <= 0.02

    dimensions2 = row_dimensions(response2)
    referals_ok = dimensions2 && !(dimensions2.flatten.any? { |word| word.include? @domain })

    bounce_rate_ok && not_set_percentage_ok && referals_ok
  end

  def filltering_spam
    request = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:hostname'), google_dimension('ga:browserVersion'), google_dimension('ga:browserSize'), google_dimension('ga:screenResolution')],
      metrics: [google_metric('ga:sessions')],
      date_ranges: [default_date_range]
    )
    response = @report.batch_get_reports(request)
    dimensions = row_dimensions(response)
    metrics = row_metric_values(response)
    return false unless dimensions && metrics

    results = dimensions.zip(metrics)
    other_hostnames = results.select { |x| x[0][0] != @domain[4..-1] }
    other_hostname_count = other_hostnames.map{ |x| x[1][0].to_i }.inject(:+)
    total_hostmane_count = results.map{ |x| x[1][0].to_i }.inject(:+)
    hostname_ratio_ok = (other_hostname_count.to_f / total_hostmane_count) <= 0.02

    version_regex =    /(^(([0-9]+\.)+[0-9]+|[-_a-z0-9\+\s]+)+|^\(not set\)|^)$/
    size_regex =       /(^[0-9]+x[0-9]+|^\(not set\)|^)$/
    spam_results = results.select { |x| (
      !(x[0][1] =~ version_regex) ||
      !(x[0][2] =~ size_regex) ||
      !(x[0][3] =~ size_regex)
    )}
    spam_count_ok = (spam_results.map{ |x| x[1][0].to_i }.inject(:+).to_i <= 10)

    hostname_ratio_ok && hostname_ratio_ok
  end

  def goal_completions
    metric_list1 = []
    metric_list2 = []
    while metric_list1.count < 10
      metric_list1[metric_list2.count] = google_metric("ga:goal#{metric_list2.count + 1}Completions")
      metric_list2[metric_list2.count] = google_metric("ga:goal#{metric_list2.count + 11}Completions")
    end
    request1 = google_report_request(
      view_id: @view_id,
      dimensions: [],
      metrics: metric_list1,
      date_ranges: [default_date_range]
    )
    request2 = google_report_request(
      view_id: @view_id,
      dimensions: [],
      metrics: metric_list2,
      date_ranges: [default_date_range]
    )
    response1 = @report.batch_get_reports(request1)
    response2 = @report.batch_get_reports(request2)

    all_resluts = total_values(response1) + total_values(response2)
    all_resluts.select { |x| x.to_i > 0 }.count > 2
  end

  def demographics
    request1 = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:interestAffinityCategory')],
      metrics: [],
      date_ranges: [default_date_range]
    )
    request2 = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:userGender')],
      metrics: [],
      date_ranges: [default_date_range]
    )
    request3 = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:userAgeBracket')],
      metrics: [],
      date_ranges: [default_date_range]
    )
    request4 = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:interestInMarketCategory')],
      metrics: [],
      date_ranges: [default_date_range]
    )
    response1 = @report.batch_get_reports(request1)
    response2 = @report.batch_get_reports(request2)
    response3 = @report.batch_get_reports(request3)
    response4 = @report.batch_get_reports(request4)

    all_resluts = total_values(response1) + total_values(response2) +
                  total_values(response3) + total_values(response4)
    all_resluts.select { |x| x.to_i > 0 }.count == 4
  end

  def events
    request = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:eventCategory')],
      metrics: [google_metric('ga:totalEvents')],
      date_ranges: [default_date_range]
    )
    response = @report.batch_get_reports(request)
    metrics = row_metric_values(response)
    metrics && metrics.flatten.select { |x| x.to_i > 0 }.count > 2
  end

  def enhanced_ecommerce
    request1 = google_report_request(
      view_id: @view_id,
      dimensions: [],
      metrics: [google_metric('ga:transactionRevenue')],
      date_ranges: [default_date_range]
    )
    request2 = google_report_request(
      view_id: @view_id,
      dimensions: [],
      metrics: [google_metric('ga:buyToDetailRate')],
      date_ranges: [default_date_range]
    )
    response1 = @report.batch_get_reports(request1)
    response2 = @report.batch_get_reports(request2)

    all_resluts = total_values(response1) + total_values(response2)
    all_resluts.select { |x| x.to_i > 0 }.count == 2
  end

  def goal_value
    request = google_report_request(
      view_id: @view_id,
      dimensions: [],
      metrics: [google_metric('ga:goalValueAll')],
      date_ranges: [default_date_range]
    )
    response = @report.batch_get_reports(request)
    total_values(response).first.to_f > 0
  end

  def adwords_linked
    request = google_report_request(
      view_id: @view_id,
      dimensions: [],
      metrics: [google_metric('ga:impressions')],
      date_ranges: [default_date_range]
    )
    response = @report.batch_get_reports(request)
    metrics = row_metric_values(response)
    metrics && metrics.flatten.map(&:to_i).inject(:+).to_i > 0
  end

  def channel_groups
    request = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:channelGrouping')],
      metrics: [],
      date_ranges: [google_date_ranges('1000DaysAgo', 'today')]
    )
    response = @report.batch_get_reports(request)
    dimensions = row_dimensions(response)

    return false unless dimensions

    (dimensions.flatten - DEFAULT_CHANNELS).any?
  end

  def content_groups
    request = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:contentGroup1')],
      metrics: [google_metric('ga:sessions')],
      date_ranges: [default_date_range]
    )
    response = @report.batch_get_reports(request)

    has_sessions = total_values(response).first.to_i > 0
    has_groups = row_dimensions(response) && row_dimensions(response).count > 1
    has_sessions && has_groups
  end

  def total_sessions
    request = google_report_request(
      view_id: @view_id,
      dimensions: [],
      metrics: [google_metric('ga:sessions')],
      date_ranges: [default_date_range]
    )
    response = @report.batch_get_reports(request)
    metrics = row_metric_values(response)
    return false unless metrics
    metrics.flatten.map(&:to_i).inject(:+).to_i
  end

  def bounce_rate
    request = google_report_request(
      view_id: @view_id,
      dimensions: [],
      metrics: [google_metric('ga:bounceRate')],
      date_ranges: [default_date_range]
    )
    response = @report.batch_get_reports(request)
    metrics = row_metric_values(response)
    return false unless metrics
    metrics.flatten.first.to_f.round(2).to_s + '%'
  end

  def traffic_majority
    request = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:channelGrouping')],
      metrics: [google_metric('ga:sessions')],
      date_ranges: [default_date_range]
    )
    response = @report.batch_get_reports(request)
    dimensions = row_dimensions(response)
    metrics = row_metric_values(response)

    return false unless dimensions && metrics
    results = dimensions.zip(metrics)
    sessions = results.map { |x| x[1][0].to_i }.max
    total_sessions = results.map { |x| x[1][0].to_i }.inject(:+)
    percentage = (sessions.to_f * 100 / total_sessions).round(2).to_s + '%'
    channel = results.select { |x| x[1][0].to_i == sessions }.flatten[0]

    { channel: channel,
      sessions: sessions,
      percentage: percentage }
  end

  def top_hostname
    request = google_report_request(
      view_id: @view_id,
      dimensions: [google_dimension('ga:hostname')],
      metrics: [google_metric('ga:entrances')],
      date_ranges: [default_date_range]
    )
    response = @report.batch_get_reports(request)
    dimensions = row_dimensions(response)
    metrics = row_metric_values(response)

    return false unless dimensions && metrics
    results = dimensions.zip(metrics)
    entrances = results.map { |x| x[1][0].to_i }.max
    results.select { |x| x[1][0].to_i == entrances }.flatten[0]
  end

  private

  def google_dimension(name)
    Google::Apis::AnalyticsreportingV4::Dimension.new(name: name)
  end

  def google_metric(expression)
    Google::Apis::AnalyticsreportingV4::Metric.new(expression: expression)
  end

  def google_date_ranges(start_date, end_date)
    Google::Apis::AnalyticsreportingV4::DateRange.new(start_date: start_date, end_date: end_date)
  end

  def google_report_request(view_id:, dimensions:, metrics:, date_ranges:)
    Google::Apis::AnalyticsreportingV4::GetReportsRequest.new(
      report_requests: [Google::Apis::AnalyticsreportingV4::ReportRequest.new(
        view_id: view_id,
        dimensions: dimensions,
        metrics: metrics,
        date_ranges: date_ranges
      )]
    )
  end

  def default_date_range
    google_date_ranges('30DaysAgo', 'today')
  end

  def total_values(response)
    response.reports.first.data.totals.first.values
  rescue
    []
  end

  def row_metric_values(response)
    response.reports.first.data.rows.map(&:metrics).flatten.map(&:values)
  rescue
    false
  end

  def row_dimensions(response)
    response.reports.first.data.rows.map(&:dimensions)
  rescue
    false
  end
end
