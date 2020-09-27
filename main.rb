require 'dotenv'
require 'json'
require 'net/http'
require 'selenium-webdriver'
require 'uri'

Dotenv.load(Dir.pwd + '/.env')

file = File.open Dir.pwd + '/manga.json'
@json_manga = JSON.load file

def send_to_telegram(manga, list_updated_chapter)
    if list_updated_chapter.length() > 0
        caption = build_message(manga, list_updated_chapter)
        Net::HTTP.post_form URI("https://api.telegram.org/bot#{ENV['TELEGRAM_BOT_TOKEN']}/sendPhoto"), { 'photo' => manga['images'][manga['images'].length() - 1], 'chat_id' => ENV['TELEGRAM_CHAT_ID'], 'caption' => caption }
        update_last_chapter(manga, list_updated_chapter)
    end
end

def build_message(manga, list_updated_chapter)
    message = ''

    list_updated_chapter.reverse().each { |m| 
        message += "[NEW UPDATE]\n#{manga['title']}\nChapter: #{m['text']}\nUpdated At: #{m['updated_at']} ago\nClick here to read #{m['url']}\n\n"
    }

    return message
end

def update_last_chapter(manga, list_updated_chapter)
    @json_manga.each { |f| 
        if f['title'].eql?(manga['title'])
            f['last_chapter'] = list_updated_chapter[0]['text']
        end
    }

    File.open(Dir.pwd + '/manga.json', 'w') do |f|
        f.write(JSON.pretty_generate(@json_manga))
    end
end

options = {
        args: ['headless', 'disable-gpu', 'disable-notifications', 'log-level=3'],
        w3c: true,
        mobileEmulation: {},
        prefs: {
            :protocol_handler => {
                :excluded_schemes => {
                    tel: false
            }
        }
    }
}

caps = Selenium::WebDriver::Chrome::Options.new(options: options)

driver = Selenium::WebDriver.for(:chrome, options: caps)

@json_manga.each { |m| 
    driver.get m['url']

    all_chapter = []

    i = 2
    i1 = 0
    index_manga = 0

    while true do
        element = driver.find_element(:xpath => "/html/body/div[1]/div[3]/div/div[#{i}]/div/div/div[2]/a") rescue nil
        element1 = driver.find_element(:xpath => "/html/body/div[1]/div[3]/div/div[#{i}]/div/div/div[4]") rescue nil

        if element != nil
            if element.text.eql?(m['last_chapter'])
                index_manga = i1
            end

            all_chapter.push({
                'text' => element.text,
                'url' => element.attribute('href'),
                'updated_at' => element1.text
            })

            i += 1
            i1 += 1
        else
            break
        end
    end

    all_chapter[index_manga..-1] = []

    send_to_telegram(m, all_chapter)
}
