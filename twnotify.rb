require 'tweetstream'
require 'http'
require 'open-uri'
TweetStream.configure do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = ENV['OAUTH_TOKEN']
  config.oauth_token_secret = ENV['OAUTH_SECRET']
  config.auth_method        = :oauth
end

class HashtagLoader
  attr_accessor :thread, :keywords, :callback, :tweet_id_history
  def initialize &block
    self.tweet_id_history = []
    self.keywords = []
    self.callback = block
  end
  def track keywords
    old_thread = thread
    return if keywords.sort == self.keywords.sort
    self.keywords = keywords
    if keywords.empty?
      self.thread = nil
    else
      p keywords
      self.thread = Thread.new{
        TweetStream::Client.new.track *keywords do |status|
          begin
            oncallback status
          rescue => e
            p e
          end
        end
      }
    end
    old_thread.exit if old_thread
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
  if ENV['KEYWORDS_URL']
    JSON.parse open(ENV['KEYWORDS_URL']).read
  else
    keywords = gets.split
  end
end

loader = HashtagLoader.new{|status|
  json = {
    id: status.id,
    text: status.text,
    hashtags: status.hashtags.map(&:text),
    urls: status.urls.map(&:expanded_url),
    user_mentions: status.user_mentions.map(&:screen_name),
    created_at: status.created_at,
    user: {
      name: status.user.name,
      screen_name: status.user.screen_name,
      profile_image_url: status.user.profile_image_url
    }
  }
  if ENV['POST_URL']
    HTTP.post ENV['POST_URL'], json: json
  else
    p json
  end
}

loop{
  p get_keywords
  loader.track get_keywords
  sleep 10
}
