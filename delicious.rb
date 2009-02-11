#!/usr/local/bin/ruby

require 'mysql'
require 'date'
require 'digest/md5'
require 'simple-json'
require 'net/http'
require 'uri'


# get all elements
bookmark_counts = []
db = Mysql.new('mysql.db.sakura.ne.jp', 'user', 'password', 'table')
res = db.query('SELECT * FROM mt_bookmark_count inner join mt_entry on mt_bookmark_count.bookmark_count_entry_id=mt_entry.entry_id')
res.each_hash do | row |
	bookmark_counts.push row
end


bookmark_data = {}
bookmark_counts.each do | bookmark_count |
	hatena_bookmark_count = bookmark_count['bookmark_count_hatena_counter']
	livedoor_bookmark_count =bookmark_count['bookmark_count_livedoor_counter']
	delicious_bookmark_count = 0
	base_name = bookmark_count['entry_basename']
	
	# get created year and month
	entry_created_date = Date.strptime( bookmark_count['entry_created_on'] ) 
	entry_created_year = entry_created_date.year	.to_s
	entry_created_month = entry_created_date.month<10? "0" + entry_created_date.month.to_s : entry_created_date.month.to_s 
	
	target_url = "http://blog.katsuma.tv/" + entry_created_year + "/" + entry_created_month + "/" + base_name + ".html"
	target_url_hash = Digest::MD5.hexdigest(target_url)
	
	# store bookmark data
	bookmark_data[target_url_hash] = {
		'hatena_bookmark_count' =>  hatena_bookmark_count,
		'livedoor_bookmark_count' => livedoor_bookmark_count,
		'delicious_bookmark_count' => delicious_bookmark_count,
		'bookmark_count_entry_id' => bookmark_count['entry_id']
	}
end


# get bookmarked_counter
bookmark_index = 1
hash_data = []
api_url = "http://feeds.delicious.com/v2/json/urlinfo/blogbadge?"

bookmark_data.each_key{ | bookmark_hash |
	hash_data.push( "hash=" + bookmark_hash )
	
	if(bookmark_index % 15 ==0 || bookmark_index>=bookmark_data.size)
		uri = URI(api_url + hash_data.join('&'))	
		Net::HTTP.start(uri.host, uri.port) do |http|
			req = Net::HTTP::Get.new(uri.request_uri)
			http.request(req) do |response|
				parser = JsonParser.new
				delicious_bookmarks = parser.parse response.body
				delicious_bookmarks.each { | delicious_bookmark | 
					bookmark_data[ delicious_bookmark['hash'] ]['delicious_bookmark_count'] = delicious_bookmark['total_posts'].to_s
				}
			sleep 1
			end
		end
		hash_data = []
	
	end
	bookmark_index += 1	
} 
	

# save data
bookmark_data.each_key { | hash_key |
	data =  bookmark_data[hash_key]
	bookmark_count_entry_id = data['bookmark_count_entry_id'] 
	hatena_bookmark_count = data['hatena_bookmark_count'] 
	delicious_bookmark_count = data['delicious_bookmark_count']
	livedoor_bookmark_count = data['livedoor_bookmark_count']
	bookmark_count_total_counter = hatena_bookmark_count.to_i + delicious_bookmark_count.to_i + livedoor_bookmark_count.to_i 
	
	p "update mt_bookmark_counts set delicious_bookmark_count=" + delicious_bookmark_count.to_s + ",  bookmark_count_total_counter=" +  bookmark_count_total_counter.to_s + " where bookmark_count_entry_id=" + bookmark_count_entry_id.to_s
	db.query("update mt_bookmark_count set bookmark_count_delicious_counter=" + delicious_bookmark_count.to_s + ",  bookmark_count_total_counter=" +  bookmark_count_total_counter.to_s + " where bookmark_count_entry_id=" + bookmark_count_entry_id.to_s)
}

db.close
