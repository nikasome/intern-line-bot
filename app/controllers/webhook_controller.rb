require 'line/bot'
require 'net/http'
require 'uri'
require 'json'

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化
  
	HAVE_A_JIRO = ["品川", "船橋", "池袋", "八王子", "新宿", "調布", "目黒"]

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

					message = {		#default message
            	type: 'text',
            	text: '二郎ありません'
         	}
					if HAVE_A_JIRO.include?(event.message['text'])
						result = get_info(event.message['text'])
						message['text'] = result[0] + "\n" + result[1] + "\n" + result[2]
						for i in result do
							p i
						end
					end

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

	def get_info(area)
		url = URI.parse("https://api.gnavi.co.jp")
		http = Net::HTTP.new(url.host, url.port)
		http.use_ssl = true
		params = URI.encode_www_form({keyid: ENV["KEY_ID"], name: 'ラーメン二郎', freeword: area}) 
		req = Net::HTTP::Get.new("/RestSearchAPI/v3/?#{params}")
		res = http.request(req)

		###code_api   &&  parse_api
		api_response = JSON.parse(res.body)

		return api_result = [
			api_response['rest'][0]['name'],		#店舗名
			api_response['rest'][0]['address'],	#店舗住所
			api_response['rest'][0]['url']			#店舗URL
		]

		#return <String>
		#statuscodeで処理
	end
end
