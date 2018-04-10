require 'google/apis/analytics_v3'

class AnalyticsManagement
  def initialize(token, web_property_id)
    @analytics = Google::Apis::AnalyticsV3::AnalyticsService.new
    @analytics.authorization = token
    @web_property_id = web_property_id
  end

  def raw_or_testing_view
    account_id = @web_property_id.split('-')[1]

    profiles = @analytics.list_profiles(account_id, @web_property_id)
    number_of_views_ok = profiles.items.count >= 3

    names = profiles.items.map { |x| x.name.downcase }
    has_test_view = names.any? { |name| (name.include? 'raw') || (name.include? 'test') }
    has_test_view && number_of_views_ok
  end
end
