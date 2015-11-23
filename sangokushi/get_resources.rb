require 'selenium-webdriver'
require 'pry'

class Sangokushi
  RESOURCE_NAME_MAP = {
    wood: "伐採所",
    stone: "石切り場",
    iron: "製鉄所",
    food: "畑",
  }

  def self.driver
    @driver ||= Selenium::WebDriver.for :firefox
  end

  def self.login
    driver.get "http://www.3gokushi.jp/"
    # id = mail_address
    driver.find_element(:id, 'mail_address').send_keys('kubonagarei@gmail.com')
    # id = password
    driver.find_element(:id, 'password').send_keys('reiemi0920')
    # input type=image title ログイン
    driver.find_elements(:class, 'imgover').select{|e| e.attribute(:title) == "ログイン"}.first.click

    ### ゲームスタート
    driver.find_element(:class, 'login_now').find_elements(:xpath, 'form/input[2]').first.click

    ### サーバーの選択
    driver.find_element(:id, 'serverLatest').click

    ### 地図画面 <http://w12.3gokushi.jp/village.php>
    ## ログインボーナスのポップアップが表示されると消す
    popup = driver.find_element(:id, 'login-bonus-close-bottom_img')
    if popup && popup.displayed?
      popup.click
    end
  end

  def self.go_to_buildings
    driver.get "http://w12.3gokushi.jp/village.php"
  end

  def self.can_build
    ## id=buildList 実行中の作業
    build_list = driver.find_element(:id, 'buildList').find_elements(:xpath, "li")

    enable = true
    build_list.each do |build|
      if build.text.include?("建設準備中")
        enable = false
      end
    end
    enable
  end

  # {wood, stone, iron, food, fame}
  def self.resources
    text = driver.find_element(:class, 'resorces').text
    text = text.gsub(" ", "").gsub("\n", "")
    names = [:wood, :stone, :iron, :food, :fame]
    arr = text.split("/")
    text.split("|").each_with_index.map do |str, i|
      a=str.split('/')
      {names[i] => {now: a[0].to_i, max: a[1].to_i}}
    end
  end

  def self.buildings
    areas = driver.find_element(id: "mapOverlayMap").find_elements(xpath: 'area')
    areas.map do |area|
      name, level_str = area.attribute("alt").split(" ")
      level = level_str ? level_str.gsub("LV.", "").to_i : nil
      {href: area.attribute("href"), level: level, name: name}
    end
  end

  def self.switch_village(n = 1)
    links = driver.find_elements(class: "sideBoxInner")[1].find_elements(xpath: "ul/li[#{n}]/a")
    if links.size > 1
      links.first.click
    end
  end

  def self.build_min_level_facility(names = [:wood, :stone, :iron, :food])
    buildings = Sangokushi.buildings
    hash = buildings.select{|h| h[:level] }.select{|h| names.map{|n| Sangokushi::RESOURCE_NAME_MAP[n]}.include?(h[:name])}.sort_by{|h| h[:level] }.first
    self.level_up_facility(url: hash[:href])
  end

  def self.level_up_facility(url: url, x: x, y: y)
    if url
      driver.get url
    else
      driver.get "http://w12.3gokushi.jp/facility/facility.php?x=#{x}&y=#{y}"
    end
    sleep(2)
    images = driver.find_element(:class, 'lvupFacility').find_elements(:xpath, "p/a/img[1]")
    if images.size > 0
      images.first.click
    end
  end

  def self.auto_actions
    driver.get "http://w12.3gokushi.jp/village.php"
    if can_build
      self.build_min_level_facility([:wood, :stone, :iron])
    end

    if Time.now.min == 0
      self.fight_all_duels
    end

    sleep(60)
    self.auto_actions
  end

  def self.fight_all_duels
    driver.get "http://w12.3gokushi.jp/pvp_duel/duel.php"
    driver.find_element(:id, 'duel_deck').find_elements(:xpath, "a[1]").first.click
    battles = driver.find_elements(:class, 'btn_battle')
    if battles.size > 0
      battles.first.click
      name = driver.find_element(:id, 'TB_iframeContent').attribute("name")
      driver.switch_to.frame(name)
      driver.find_element(:id, 'battle_start_button').click
      sleep(3)
      self.fight_all_duels
    end
  end
end

Sangokushi.login

#sleep(3)

Sangokushi.switch_village(4)

#sleep(3)

Sangokushi.auto_actions

