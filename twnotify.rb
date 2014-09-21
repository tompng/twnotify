require 'tweetstream'
require 'http'
TweetStream.configure do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = ENV['OAUTH_TOKEN']
  config.oauth_token_secret = ENV['OAUTH_SECRET']
  config.auth_method        = :oauth
end

class HashtagLoader
  attr_accessor :client, :keywords, :callback, :tweet_id_history
  def initialize &block
    self.tweet_id_history = []
    self.callback = block
  end
  def track keywords
    old_client = client
    return if keywords.sort == self.keywords.sort
    self.keywords = keywords
    if keywords.present?
      self.client = TweetStream::Client.new.track keywords do |status|
        oncallback status
      end
    else
      self.client = nil
    end
    old_client.stop if old_client
  end

  def tweet_id_push id
    tweet_id_history.push id
    tweet_id_history.shift if tweet_id_history.size > 100
  end

  def tweet_id_pushed? id
    tweet_id_history.include? id
  end

  def oncallback status
    id = status.id
    return if tweet_id_pushed? id
    tweet_id_push id
    callback.call status
  end
end

def get_keywords
  JSON.parse HTTP.get(ENV['KEYWORDS_URL'])
end

loader = HashtagLoader.new{|status|
  HTTP.post(ENV['POST_URL'], status)
}
loop{
  sleep 10
  loader.track get_keywords
}
