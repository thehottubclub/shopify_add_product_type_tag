require 'json'
require 'httparty'
require 'pry'
require 'shopify_api'
require 'yaml'

@outcomes = {
  errors: [],
  skipped: [],
  didnt_update_product_tags: [],
  saved_product_tags: [],
  unable_to_save_product: [],
  unable_to_add_tags: [],
  cant_find_product_type_in_metafields_hash: [],
  responses: []
}

#Load secrets from yaml file & set values to use
data = YAML::load(File.open('config/secrets.yml'))
SECURE_URL_BASE = data['url_base']
API_DOMAIN = data['api_domain']

#Constants
DIVIDER = '------------------------------------------'
DELAY_BETWEEN_REQUESTS = 0.11
NET_INTERFACE = HTTParty
STARTPAGE = 1
ENDPAGE = 97

#Comment out and product types you don't wish to seach for
TYPE_TO_TAGS_HASH = {
  ['Aprons'] => ['accessories','accessory','aprons', 'gifts'],
  ['Bandanas'] => ['accessories', 'accessory', 'bandanas'],
  ['Beanies'] => ['accessories', 'accessory', 'beanies'],
  ['Blazers'] => ['formal', 'suits', 'blazers', 'tops'],
  ['Bombers'] => ['outerwear', 'bombers'],
  ['Boot Toppers'] => ['accessories', 'accessory', 'boot toppers'],
  ['Bow Ties'] => ['formal', 'suits', 'accessory', 'accessories', 'bow ties'],
  ['Boxers'] => ['bottoms', 'shorts', 'boxers'],
  ['Button Downs'] => ['tops', 'button downs'],
  ['Cardigans'] => ['tops', 'cardigans'],
  ['Combos'] => ['accessories', 'accessory', 'combos'],
  ['Crop Tops'] => ['tops', 'crop tops'],
  ['Dresses'] => ['dresses'],
  ['Drinking'] => ['guys', 'gals', 'accessory', 'accessories'],
  ['Facemasks'] => ['accessories', 'accessory', 'facemasks'],
  ['Fanny Packs'] => ['accessories', 'accessory', 'fanny packs'],
  ['Fleeces'] => ['outerwear', 'ski', 'fleeces'],
  ['Gifts'] => ['accessories', 'accessory', 'gifts'],
  ['Gloves'] => ['accessories', 'accessory', 'gloves', 'ski'],
  ['Hammer Pants'] => ['bottoms', 'hammer pants'],
  ['Hats'] => ['accessories', 'accessory', 'hats', 'hat'],
  ['Headbands'] => ['accessories', 'accessory', 'headbands', 'headband'],
  ['Jerseys'] => ['sports', 'tops', 'jerseys', 'jersey'],
  ['Joggers'] => ['bottoms', 'joggers', 'pants'],
  ['Leather Jackets'] => ['outerwear', 'jackets', 'leather jackets'],
  ['Leggings'] => ['bottoms', 'leggings'],
  ['Leisure Shirts'] => ['tops', 'leisure', 'beach', 'leisure shirts'],
  ['Light Jackets'] => ['outerwear', 'light jackets', 'jackets'],
  ['Long Sleeves'] => ['tops', 'long sleeves'],
  ['Mullets'] => ['accessories', 'accessory', 'mullet', 'mullets', 'hats', 'hat'],
  ['Onesies'] => ['onesie', 'onesies'],
  ['Overalls'] => ['bottoms', 'overalls'],
  ['Pants'] => ['bottoms', 'pants'],
  ['Polos'] => ['tops', 'polos'],
  ['Rompers'] => ['bottoms', 'tops', 'dresses', 'rompers'],
  ['Scarves'] => ['accessories', 'accessory', 'scarf', 'scarves'],
  ['Xmas Sweaters'] => ['tops', 'xmas sweaters', 'sweaters'],
  ['Suits'] => ['formal', 'suits'],
  ['Suit Pants'] => ['formal', 'suits', 'pants', 'bottoms', 'suit pants'],
  ['Shorts'] => ['bottoms', 'shorts'],
  ['Ski Jackets'] => ['ski', 'jackets', 'outerwear', 'ski jackets'],
  ['Ski Masks'] => ['ski', 'ski masks', 'accessory', 'accessories'],
  ['Ski Overalls'] => ['ski', 'bottoms', 'overalls', 'ski overalls', 'bibs'],
  ['Ski Pants'] => ['ski', 'bottoms', 'pants', 'ski pants'],
  ['Ski Suits'] => ['onesie', 'onesies'],
  ['Skirts'] => ['bottoms', 'skirts'],
  ['Socks'] => ['accessory', 'accessories', 'socks'],
  ['Sunglasses'] => ['accessory', 'accessories', 'sunglasses'],
  ['Suspenders'] => ['accessory', 'accessories', 'formal', 'suits', 'suspenders'],
  ['Sweatbands'] => ['accessory', 'accessories', 'sweatbands'],
  ['Sweaters'] => ['tops', 'sweaters'],
  ['Sweatshirts'] => ['tops', 'sweatshirts'],
  ['Swimwear'] => ['bottoms', 'beach', 'leisure', 'swimwear'],
  ['Swish Pants'] => ['bottoms', 'pants', '90s', 'swish pants'],
  ['Tanks'] => ['tops', 'tanks'],
  ['Tees'] => ['tops', 'tees'],
  ['Ties'] => ['formal', 'suits', 'ties'],
  ['Vests'] => ['tops', 'vests'],
  ['Windbreakers'] => ['outerwear', 'windbreakers']
}

#Need to update to include page range as arguments for do_page_range
# startpage = ARGV[0].to_i
# endpage = ARGV[1].to_i
def main
  puts "adding tags to products based on type"
  puts "starting at #{Time.now}"

  if ARGV[0] =~ /product_id=/
    do_product_by_id(ARGV[0].scan(/product_id=(\d+)/).first.first)
  else
    do_page_range
  end

  puts "finished at #{Time.now}"
  puts "finished adding tags to products based on type"

  File.open(filename, 'w') do |file|
    file.write @outcomes.to_json
  end

  @outcomes.each_pair do |k,v|
    puts "#{k}: #{v.size}"
  end
end

def filename
  "data/add_tags_by_product_type_#{Time.now.strftime("%Y-%m-%d_%k%M%S")}.json"
end

def do_page_range
  (STARTPAGE .. ENDPAGE).to_a.each do |current_page|
    do_page(current_page)
  end
end

def do_page(page_number)
  puts "Starting page #{page_number}"

  products = get_products(page_number)

  # counter = 0
  products.each do |product|
    @product_id = product['id']
    do_product(product)
  end

  puts "Finished page #{page_number}"
end

def get_products(page_number)
  response = secure_get("/products.json?page=#{page_number}")

  JSON.parse(response.body)['products']
end

def get_product(id)
  JSON.parse( secure_get("/products/#{id}.json").body )['product']
end

def do_product_by_id(id)
  do_product(get_product(id))
end

def do_product(product)
  begin
    puts DIVIDER
    product_type = product['product_type']
    # tags_to_add = ["accessories","accessory","aprons"]
    old_tags = product['tags'].split(', ')

    # if( should_skip_based_on?(product_type) )
    #   skip(product)
    # else

    if tags_to_add = find_tags_to_add_based_on_type(product_type)
      add_new_tags_to_product(product, old_tags, tags_to_add)
    else
      @outcomes[:cant_find_product_type_in_metafields_hash].push @product_id
      puts "Couldn't find product type in metafields hash for #{product['product_type']} #{product['id']}"
    end
  rescue Exception => e
    @outcomes[:errors].push @product_id
    puts "error on product #{product['id']}: #{e.message}"
    puts e.backtrace.join("\n")
    raise e
  end
end

def find_tags_to_add_based_on_type(product_type)
  TYPE_TO_TAGS_HASH.each_pair do |type, tags|
    if(type.include?(product_type))
      return tags
    end
  end
  return false
end

def skip(product)
  @outcomes[:skipped].push @product_id
  puts "Skipping product #{product['id']}"
end

def add_new_tags_to_product(product, old_tags, tags_to_add)
  temp_old_tags = old_tags.map do |tag| tag.dup end
  if new_tags = replace_tag(temp_old_tags, tags_to_add)
    if new_tags.uniq.sort == old_tags.uniq.sort
      @outcomes[:didnt_update_product_tags].push @product_id
      puts "No update for #{product['product_type']} product: #{product['id']}"
    else
      if result = save_tags(product, new_tags)
        @outcomes[:saved_product_tags].push @product_id
        puts "Saved tags for #{product['product_type']} #{product['id']}: #{new_tags}"
      else
        @outcomes[:unable_to_save_tags].push @product_id
        puts "Unable to save tags for #{product['id']}:  #{result.body}"
      end
    end
  else
    @outcomes[:unable_to_add_tags].push @product_id
    puts "unable to replace tags_for product #{product['id']}"
  end
end

def replace_tag(temp_old_tags, tags_to_add)
  tags_to_add.each do |tag|
    unless temp_old_tags.include?(tag)
      temp_old_tags.push(tag)
    end
  end
  return temp_old_tags
end

def save_tags(product, new_tags)
  secure_put(
    "/products/#{product['id']}.json",
    {product: {id: product['id'], tags: new_tags}}
  )
end


def secure_get(relative_url)
  sleep DELAY_BETWEEN_REQUESTS
  url = SECURE_URL_BASE + relative_url
  result = NET_INTERFACE.get(url)
end

def secure_put(relative_url, params)
  sleep DELAY_BETWEEN_REQUESTS

  url = SECURE_URL_BASE + relative_url

  result = NET_INTERFACE.put(url, body: params)

  @outcomes[:responses].push({
    method: 'put', requested_url: url, body: result.body, code: result.code
  })
end

def put(url, params)
  NET_INTERFACE.put(url, query: params)
end

main
