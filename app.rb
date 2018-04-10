require 'rubygems'
require 'sinatra'
require 'byebug'
# ENVs used for testing
require 'dotenv'
Dotenv.load

require './services/analytics_reporting'
require './services/analytics_management'

get '/test' do
  analytics = Google::Apis::AnalyticsV3::AnalyticsService.new
  analytics.authorization = params[:token]

  accounts = analytics.list_accounts
  account_id = accounts.items[1].id

  web_properties = analytics.list_web_properties(account_id)
  web_property_id = web_properties.items.first.id

  profiles = analytics.list_profiles(account_id, web_property_id)
  profile_id = profiles.items.first.id

  goals = analytics.list_goals(account_id, web_property_id, profile_id)
  goals.to_json
end

get '/api/accurate' do
  content_type :json
  validate_all_params!
  result_hash = {}
  begin
    result_hash[:setup_correct] =
      AnalyticsReporting.new(params[:token], params[:view_id], params[:domain])
                        .setup_correct
    result_hash[:filltering_spam] =
      AnalyticsReporting.new(params[:token], params[:view_id], params[:domain])
                        .filltering_spam
    result_hash[:raw_or_testing_view] =
      AnalyticsManagement.new(params[:token], params[:property])
                         .raw_or_testing_view
  rescue Google::Apis::AuthorizationError => e
    halt 401, { error: e.to_s }.to_json
  rescue StandardError => e
    halt 400, { error: e.to_s }.to_json
  end
  result_hash.to_json
end

get '/api/actionable' do
  content_type :json
  validate_base_params!
  result_hash = {}
  begin
    result_hash[:goals_set_up] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .goal_completions
    result_hash[:demographic_data] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .demographics
    result_hash[:events] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .events
    result_hash[:enhanced_ecommerce] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .enhanced_ecommerce
    result_hash[:goal_value] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .goal_value
  rescue Google::Apis::AuthorizationError => e
    halt 401, { error: e.to_s }.to_json
  rescue StandardError => e
    halt 400, { error: e.to_s }.to_json
  end
  result_hash.to_json
end

get '/api/accessible' do
  content_type :json
  validate_base_params!
  result_hash = {}
  begin
    result_hash[:adwords_linked] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .adwords_linked
    result_hash[:channel_groups] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .channel_groups
    result_hash[:content_groups] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .content_groups
  rescue Google::Apis::AuthorizationError => e
    halt 401, { error: e.to_s }.to_json
  rescue StandardError => e
    halt 400, { error: e.to_s }.to_json
  end
  result_hash.to_json
end

get '/api/other_data_pulls' do
  content_type :json
  validate_base_params!
  result_hash = {}
  begin
    result_hash[:total_sessions] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .total_sessions
    result_hash[:bounce_rate] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .bounce_rate
    result_hash[:traffic_majority] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .traffic_majority
    result_hash[:top_hostname] =
      AnalyticsReporting.new(params[:token], params[:view_id])
                        .top_hostname
  rescue Google::Apis::AuthorizationError => e
    halt 401, { error: e.to_s }.to_json
  rescue StandardError => e
    halt 400, { error: e.to_s }.to_json
  end
  result_hash.to_json
end

def validate_base_params!
  return unless params[:token].nil? || params[:view_id].nil?
  halt 422, {error: 'Insuficient parameters (token and view_id are required)'}.to_json
end

def validate_all_params!
  return unless params[:token].nil? || params[:view_id].nil? || params[:domain].nil? || params[:property].nil?
  halt 422, {error: 'Insuficient parameters (token, view_id, domain and property are required)'}.to_json
end
