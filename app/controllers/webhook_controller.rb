require 'line/bot'
require 'net/http'
require 'uri'
require 'json'

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化
  
  RESTAURANT_NAME = "ラーメン二郎"
  GNAVI_URL = "https://api.gnavi.co.jp"
  GNAVI_RESTAURANT_API = "/RestSearchAPI/v3/?"

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head 470
    end

    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text

          message = {   #default message
              type: 'text',
              text: '二郎ありません'
          }
          
          area = event.message['text']
          restaurant_req = restaurant_request(RESTAURANT_NAME, area)
          encode_res = get_encode_res(restaurant_url, restaurant_req)
          restaurant_res = get_restaurant_parse(encode_res)
          message[:text] = restaurant_res 
          client.reply_message(event['replyToken'], message)

        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          response = client.get_message_content(event.message['id'])
          tf = Tempfile.open("content")
          tf.write(response.body)
        end
      end
    }
    head :ok
  end

  def restaurant_url
    URI.parse(GNAVI_URL)
  end

  def restaurant_request(name, area)
    params = URI.encode_www_form({keyid: ENV["KEY_ID"], name: name, freeword: area}) 
    Net::HTTP::Get.new(GNAVI_RESTAURANT_API << params)
  end

  def get_encode_res(url, req)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.request(req)
  end

  def get_restaurant_parse(encode_res)
    parse_res = JSON.parse(encode_res.body)
    <<~STR
        #{parse_res['rest'][0]['name']}

        住所:
        #{parse_res['rest'][0]['address']}
        
        URL:
        #{parse_res['rest'][0]['url']}
      STR
  rescue => e
    p e
    "Error"
  end

end
