# frozen_string_literal: true

# 在 App Store Connect 中创建 PTuner Pro 的三个付费点：
#   1. 非消耗型（一次买断）  9.99 USD
#   2. 自动续期订阅（年付）  4.99 USD / 年
#   3. 自动续期订阅（周付）  0.99 USD / 周
#
# 年付与周付放在同一个订阅组（PTuner Pro）中，便于用户升降级。
# 脚本可重复执行：已存在的产品、本地化、价格都会被跳过。
#
# 用法（通常由 fastlane lane 调用）：
#   ruby scripts/pro_products.rb --dry-run
#   ruby scripts/pro_products.rb
#
# 依赖环境变量：
#   APP_STORE_CONNECT_KEY_ID / APP_STORE_CONNECT_ISSUER_ID / APP_STORE_CONNECT_KEY_FILEPATH

require "spaceship"
require "json"

class ProProducts
  APP_ID = "6824013425"
  BUNDLE_ID = "online.c1c1.ptuner"
  GROUP_REFERENCE_NAME = "PTuner Pro"
  BASE_TERRITORY = "USA"

  NON_CONSUMABLE = {
    product_id: "#{BUNDLE_ID}.pro.lifetime",
    name: "PTuner Pro Lifetime",
    price_usd: 9.99,
    review_note: "一次性买断，永久解锁 PTuner 全部专业功能。"
  }.freeze

  SUBSCRIPTIONS = [
    {
      slug: "yearly",
      product_id: "#{BUNDLE_ID}.pro.yearly",
      name: "PTuner Pro Yearly",
      period: "ONE_YEAR",
      price_usd: 4.99,
      review_note: "按年订阅，订阅期间解锁 PTuner 全部专业功能。"
    },
    {
      slug: "weekly",
      product_id: "#{BUNDLE_ID}.pro.weekly",
      name: "PTuner Pro Weekly",
      period: "ONE_WEEK",
      price_usd: 0.99,
      review_note: "按周订阅，订阅期间解锁 PTuner 全部专业功能。"
    }
  ].freeze

  # 订阅组在 App Store 订阅管理页里显示的名称。参考名（referenceName）不面向用户，
  # 这里按 PTuner 支持的语言逐个写入。
  GROUP_NAMES = {
    "de-DE" => "PTuner Pro",
    "en-US" => "PTuner Pro",
    "es-ES" => "PTuner Pro",
    "fr-FR" => "PTuner Pro",
    "it" => "PTuner Pro",
    "ja" => "PTuner プロ版",
    "ko" => "PTuner 프로",
    "zh-Hans" => "PTuner 专业版",
    "zh-Hant" => "PTuner 專業版"
  }.freeze

  LOCALIZATIONS = {
    "zh-Hans" => {
      lifetime: { name: "PTuner Pro 永久版", description: "一次买断，永久解锁全部专业功能。" },
      yearly: { name: "PTuner Pro 年付", description: "按年订阅，持续解锁全部专业功能。" },
      weekly: { name: "PTuner Pro 周付", description: "按周订阅，灵活解锁全部专业功能。" }
    },
    "en-US" => {
      lifetime: { name: "PTuner Pro Lifetime", description: "One-time purchase. Unlock every Pro feature forever." },
      yearly: { name: "PTuner Pro Yearly", description: "Annual subscription. Unlock every Pro feature." },
      weekly: { name: "PTuner Pro Weekly", description: "Weekly subscription. Unlock every Pro feature." }
    }
  }.freeze

  def initialize(client:, dry_run: false)
    @client = client
    @dry_run = dry_run
  end

  def create_all(group_only: false)
    unless group_only
      lifetime = ensure_lifetime
      ensure_lifetime_localizations(lifetime)
      ensure_lifetime_availability(lifetime)
      ensure_lifetime_price(lifetime)
    end

    group = ensure_group
    ensure_group_localizations(group)

    if group_only
      puts "\n订阅组本地化完成：#{GROUP_REFERENCE_NAME} (id=#{group['id']})"
      return
    end

    subscriptions = SUBSCRIPTIONS.to_h do |spec|
      sub = ensure_subscription(group, spec)
      ensure_subscription_localizations(sub, spec)
      ensure_subscription_availability(sub)
      ensure_subscription_prices(sub, spec)
      [spec[:slug], sub]
    end

    puts "\n完成："
    puts "  非消耗型  #{NON_CONSUMABLE[:product_id]}  $#{NON_CONSUMABLE[:price_usd]} (id=#{lifetime['id']})"
    subscriptions.each do |slug, sub|
      spec = SUBSCRIPTIONS.find { |s| s[:slug] == slug }
      puts "  #{slug.ljust(7)}  #{spec[:product_id]}  $#{spec[:price_usd]} (id=#{sub['id']})"
    end
  end

  private

  def get(path, params = nil)
    with_retry { @client.get(path, params).body }
  end

  def post(path, body)
    if @dry_run
      puts "[dry-run] POST #{path} #{JSON.generate(body)[0, 160]}"
      return { "data" => { "id" => "dry-run" } }
    end
    @client.post(path, body).body
  end

  def ensure_lifetime
    existing = get("v1/apps/#{APP_ID}/inAppPurchasesV2", { "limit" => 200 })["data"]
    found = existing.find { |i| i.dig("attributes", "productId") == NON_CONSUMABLE[:product_id] }
    return found if found

    puts "创建非消耗型：#{NON_CONSUMABLE[:product_id]}"
    post("v2/inAppPurchases", {
      data: {
        type: "inAppPurchases",
        attributes: {
          name: NON_CONSUMABLE[:name],
          productId: NON_CONSUMABLE[:product_id],
          inAppPurchaseType: "NON_CONSUMABLE",
          reviewNote: NON_CONSUMABLE[:review_note]
        },
        relationships: { app: { data: { type: "apps", id: APP_ID } } }
      }
    })["data"]
  end

  def ensure_lifetime_localizations(lifetime)
    existing = get("v2/inAppPurchases/#{lifetime['id']}/inAppPurchaseLocalizations", { "limit" => 200 })["data"]
    existing_locales = existing.map { |l| l.dig("attributes", "locale") }

    LOCALIZATIONS.each do |locale, values|
      next if existing_locales.include?(locale)

      loc = values[:lifetime]
      puts "  本地化（非消耗型）#{locale}: #{loc[:name]}"
      post("v1/inAppPurchaseLocalizations", {
        data: {
          type: "inAppPurchaseLocalizations",
          attributes: { locale: locale, name: loc[:name], description: loc[:description] },
          relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: lifetime["id"] } } }
        }
      })
    end
  end

  def ensure_lifetime_availability(lifetime)
    existing = begin
      get("v2/inAppPurchases/#{lifetime['id']}/inAppPurchaseAvailability")
    rescue Spaceship::UnexpectedResponse
      nil
    end
    return if existing && existing["data"]

    territories = all_territory_ids
    puts "  设置可售区域（非消耗型）：#{territories.size} 个地区"
    post("v1/inAppPurchaseAvailabilities", {
      data: {
        type: "inAppPurchaseAvailabilities",
        attributes: { availableInNewTerritories: true },
        relationships: {
          inAppPurchase: { data: { type: "inAppPurchases", id: lifetime["id"] } },
          availableTerritories: {
            data: territories.map { |t| { type: "territories", id: t } }
          }
        }
      }
    })
  end

  def ensure_lifetime_price(lifetime)
    price_point = find_iap_price_point(lifetime["id"], NON_CONSUMABLE[:price_usd])
    puts "  设置非消耗型价格：$#{NON_CONSUMABLE[:price_usd]} (#{price_point})"

    post("v1/inAppPurchasePriceSchedules", {
      data: {
        type: "inAppPurchasePriceSchedules",
        relationships: {
          inAppPurchase: { data: { type: "inAppPurchases", id: lifetime["id"] } },
          baseTerritory: { data: { type: "territories", id: BASE_TERRITORY } },
          manualPrices: { data: [{ type: "inAppPurchasePrices", id: "${price1}" }] }
        }
      },
      included: [{
        type: "inAppPurchasePrices",
        id: "${price1}",
        relationships: {
          inAppPurchasePricePoint: { data: { type: "inAppPurchasePricePoints", id: price_point } },
          territory: { data: { type: "territories", id: BASE_TERRITORY } }
        }
      }]
    })
  rescue Spaceship::UnexpectedResponse => e
    # 价格计划只能创建一次；重复执行时忽略已经存在的情况。
    raise unless e.message.match?(/already|exist|conflict/i)
    puts "  价格计划已存在，跳过"
  end

  def ensure_group
    groups = get("v1/apps/#{APP_ID}/subscriptionGroups", { "limit" => 200 })["data"]
    found = groups.find { |g| g.dig("attributes", "referenceName") == GROUP_REFERENCE_NAME }
    return found if found

    puts "创建订阅组：#{GROUP_REFERENCE_NAME}"
    post("v1/subscriptionGroups", {
      data: {
        type: "subscriptionGroups",
        attributes: { referenceName: GROUP_REFERENCE_NAME },
        relationships: { app: { data: { type: "apps", id: APP_ID } } }
      }
    })["data"]
  end

  # 订阅组名称的本地化挂在“版本”上（ASC 新模型），先找 PREPARE_FOR_SUBMISSION
  # 的版本，没有就创建一个。
  def ensure_group_localizations(group)
    version = ensure_group_version(group)
    existing = get(
      "v1/subscriptionGroupVersions/#{version['id']}/localizations",
      { "limit" => 200 }
    )["data"]
    existing_locales = existing.map { |l| l.dig("attributes", "locale") }

    GROUP_NAMES.each do |locale, name|
      next if existing_locales.include?(locale)

      puts "  订阅组本地化 #{locale}: #{name}"
      post("v2/subscriptionGroupLocalizations", {
        data: {
          type: "subscriptionGroupLocalizations",
          attributes: { locale: locale, name: name },
          relationships: {
            version: { data: { type: "subscriptionGroupVersions", id: version["id"] } }
          }
        }
      })
    end
  end

  def ensure_group_version(group)
    versions = get("v1/subscriptionGroups/#{group['id']}/versions", { "limit" => 50 })["data"]
    found = versions.find { |v| v.dig("attributes", "state") == "PREPARE_FOR_SUBMISSION" }
    return found if found

    puts "创建订阅组版本：#{GROUP_REFERENCE_NAME}"
    post("v1/subscriptionGroupVersions", {
      data: {
        type: "subscriptionGroupVersions",
        relationships: {
          subscriptionGroup: { data: { type: "subscriptionGroups", id: group["id"] } }
        }
      }
    })["data"]
  end

  def ensure_subscription(group, spec)
    existing = get("v1/subscriptionGroups/#{group['id']}/subscriptions", { "limit" => 200 })["data"]
    found = existing.find { |s| s.dig("attributes", "productId") == spec[:product_id] }
    return found if found

    puts "创建订阅：#{spec[:product_id]} (#{spec[:period]})"
    post("v1/subscriptions", {
      data: {
        type: "subscriptions",
        attributes: {
          name: spec[:name],
          productId: spec[:product_id],
          subscriptionPeriod: spec[:period],
          familySharable: false,
          reviewNote: spec[:review_note]
        },
        relationships: { group: { data: { type: "subscriptionGroups", id: group["id"] } } }
      }
    })["data"]
  end

  def ensure_subscription_localizations(sub, spec)
    existing = get("v1/subscriptions/#{sub['id']}/subscriptionLocalizations", { "limit" => 200 })["data"]
    existing_locales = existing.map { |l| l.dig("attributes", "locale") }

    LOCALIZATIONS.each do |locale, values|
      next if existing_locales.include?(locale)

      loc = values[spec[:slug].to_sym]
      puts "  本地化（#{spec[:slug]}）#{locale}: #{loc[:name]}"
      post("v1/subscriptionLocalizations", {
        data: {
          type: "subscriptionLocalizations",
          attributes: { locale: locale, name: loc[:name], description: loc[:description] },
          relationships: { subscription: { data: { type: "subscriptions", id: sub["id"] } } }
        }
      })
    end
  end

  def ensure_subscription_availability(sub)
    existing = begin
      get("v1/subscriptions/#{sub['id']}/subscriptionAvailability")
    rescue Spaceship::UnexpectedResponse
      nil
    end
    return if existing && existing["data"]

    territories = all_territory_ids
    puts "  设置可售区域：#{territories.size} 个地区"
    post("v1/subscriptionAvailabilities", {
      data: {
        type: "subscriptionAvailabilities",
        attributes: { availableInNewTerritories: true },
        relationships: {
          subscription: { data: { type: "subscriptions", id: sub["id"] } },
          availableTerritories: {
            data: territories.map { |t| { type: "territories", id: t } }
          }
        }
      }
    })
  end

  def ensure_subscription_prices(sub, spec)
    current = get(
      "v1/subscriptions/#{sub['id']}/prices",
      { "limit" => 200, "include" => "subscriptionPricePoint,territory" }
    )["data"]
    priced_territories = current.map { |p| p.dig("relationships", "territory", "data", "id") }.compact

    base_price_point = find_subscription_price_point(sub["id"], spec[:price_usd])
    unless priced_territories.include?(BASE_TERRITORY)
      puts "  设置 #{spec[:slug]} 基准价格：$#{spec[:price_usd]} (#{BASE_TERRITORY})"
      create_subscription_price(sub["id"], base_price_point, BASE_TERRITORY)
      priced_territories << BASE_TERRITORY
    end

    equalizations = get(
      "v1/subscriptionPricePoints/#{base_price_point}/equalizations",
      { "limit" => 8000, "include" => "territory" }
    )["data"]

    missing = equalizations.reject do |p|
      priced_territories.include?(p.dig("relationships", "territory", "data", "id"))
    end
    return if missing.empty?

    puts "  补齐 #{spec[:slug]} 其余地区价格：#{missing.size} 个地区"
    missing.each do |p|
      territory = p.dig("relationships", "territory", "data", "id")
      create_subscription_price(sub["id"], p["id"], territory)
    end
  end

  def create_subscription_price(subscription_id, price_point_id, territory_id)
    with_retry do
      post("v1/subscriptionPrices", {
        data: {
          type: "subscriptionPrices",
          attributes: { preserveCurrentPrice: false },
          relationships: {
            subscription: { data: { type: "subscriptions", id: subscription_id } },
            subscriptionPricePoint: { data: { type: "subscriptionPricePoints", id: price_point_id } },
            territory: { data: { type: "territories", id: territory_id } }
          }
        }
      })
    end
  rescue Spaceship::UnexpectedResponse => e
    # 网络重试后可能已经写入成功，冲突视为已存在。
    raise unless e.message.match?(/already|exist|conflict/i)
  end

  # 网络抖动（尤其是走本地代理时）会让个别请求失败，简单退避重试。
  def with_retry(tries: 4)
    attempt = 0
    begin
      attempt += 1
      yield
    rescue Faraday::SSLError, Faraday::ConnectionFailed, Faraday::TimeoutError
      raise if attempt >= tries
      sleep(1.5 * attempt)
      retry
    end
  end

  def find_iap_price_point(iap_id, target_usd)
    rows = get(
      "v2/inAppPurchases/#{iap_id}/pricePoints",
      { "filter[territory]" => BASE_TERRITORY, "limit" => 8000 }
    )["data"]
    row = rows.find { |p| p.dig("attributes", "customerPrice").to_f == target_usd.to_f }
    raise "找不到 $#{target_usd} 的价格点（非消耗型）" unless row
    row["id"]
  end

  def find_subscription_price_point(subscription_id, target_usd)
    rows = get(
      "v1/subscriptions/#{subscription_id}/pricePoints",
      { "filter[territory]" => BASE_TERRITORY, "limit" => 8000 }
    )["data"]
    row = rows.find { |p| p.dig("attributes", "customerPrice").to_f == target_usd.to_f }
    raise "找不到 $#{target_usd} 的价格点（订阅）" unless row
    row["id"]
  end

  def all_territory_ids
    return @territory_ids if @territory_ids

    ids = []
    cursor = nil
    loop do
      params = { "limit" => 200 }
      params["cursor"] = cursor if cursor
      body = get("v1/territories", params)
      ids.concat(body["data"].map { |t| t["id"] })
      cursor = body.dig("links", "next")
      break unless cursor
    end
    @territory_ids = ids
  end
end

if __FILE__ == $PROGRAM_NAME
  dry_run = ARGV.include?("--dry-run")
  group_only = ARGV.include?("--group-only")

  key_id = ENV["APP_STORE_CONNECT_KEY_ID"]
  issuer_id = ENV["APP_STORE_CONNECT_ISSUER_ID"]
  key_path = ENV["APP_STORE_CONNECT_KEY_FILEPATH"]

  missing = {
    "APP_STORE_CONNECT_KEY_ID" => key_id,
    "APP_STORE_CONNECT_ISSUER_ID" => issuer_id,
    "APP_STORE_CONNECT_KEY_FILEPATH" => key_path
  }.select { |_, v| v.to_s.empty? }.keys
  abort "缺少环境变量：#{missing.join(', ')}" unless missing.empty?

  token = Spaceship::ConnectAPI::Token.create(
    key_id: key_id,
    issuer_id: issuer_id,
    filepath: key_path
  )
  client = Spaceship::ConnectAPI::Tunes::Client.new(token: token)

  ProProducts.new(client: client, dry_run: dry_run).create_all(group_only: group_only)
end
